import XCTest
@testable import NowStation

/** 서버 대신 쓰는 가짜. 다음 응답을 정해 두고, 받은 움직임을 기록한다. */
final class FakeRideRepository: RideRepository {
    var next: Result<RideView, APIError> = .success(RideView(rideId: "r1", status: .waiting, thisStation: "태평"))
    var sentMotions: [[Motion]] = []
    var ended: [String] = []

    func start(origin: String, destination: String?) async throws -> RideView { try next.get() }
    func get(rideId: String) async throws -> RideView { try next.get() }
    func sendMotion(rideId: String, motions: [Motion], sentAt: Date) async throws -> RideView {
        sentMotions.append(motions)
        return try next.get()
    }
    func end(rideId: String) async throws { ended.append(rideId) }
}

@MainActor
final class RideTrackerTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func test_지하에서_끊기면_마지막_역은_두고_연결_끊김만_표시하고_움직임은_쌓아_둔다() async throws {
        let repo = FakeRideRepository()
        let tracker = RideTracker(repository: repo, now: { self.t0 })
        try await tracker.start(origin: "태평", destination: "야탑")

        repo.next = .failure(.network)
        await tracker.report(Motion(kind: .moving, at: t0))
        XCTAssertEqual(tracker.state?.online, false)
        XCTAssertEqual(tracker.state?.view.thisStation, "태평")
        XCTAssertEqual(tracker.state?.unsentMotions, 1)

        repo.next = .success(RideView(rideId: "r1", status: .moving, line: "수인분당선", thisStation: "모란", nextStation: "야탑"))
        await tracker.refresh()
        XCTAssertEqual(repo.sentMotions.last?.count, 1, "다시 연결되면 쌓인 움직임을 보낸다")
        XCTAssertEqual(tracker.state?.online, true)
        XCTAssertEqual(tracker.state?.unsentMotions, 0)
    }

    func test_서버가_탑승을_모르면_끝내고_알린다() async throws {
        let repo = FakeRideRepository()
        let tracker = RideTracker(repository: repo)
        try await tracker.start(origin: "태평", destination: nil)

        repo.next = .failure(.notFound)
        await tracker.refresh()
        XCTAssertNil(tracker.state)
        XCTAssertTrue(tracker.lostNotice)
    }

    func test_내릴_역_알림은_켜지는_순간_한_번만() async throws {
        let repo = FakeRideRepository()
        let tracker = RideTracker(repository: repo)
        var alerts = 0
        tracker.onChange = { old, new in if ActiveRide.alightAlertStarted(before: old, after: new) { alerts += 1 } }
        try await tracker.start(origin: "태평", destination: "야탑")

        repo.next = .success(RideView(rideId: "r1", status: .moving, thisStation: "야탑", nextStation: "이매", prepareToAlight: true))
        await tracker.refresh()
        await tracker.refresh()
        XCTAssertEqual(alerts, 1)
    }

    func test_최근_경로는_맨_앞에_넣고_같은_경로는_하나만_최대_3개() {
        let a = Station(name: "태평", lines: ["수인분당선"]), b = Station(name: "야탑", lines: ["수인분당선"])
        var routes: [RecentRoute] = []
        routes = RecentRoute.push(routes, RecentRoute(origin: a, destination: b))
        routes = RecentRoute.push(routes, RecentRoute(origin: b, destination: nil))
        routes = RecentRoute.push(routes, RecentRoute(origin: a, destination: b))
        XCTAssertEqual(routes.map(\.origin.name), ["태평", "야탑"])
        for name in ["강남", "선릉", "한티"] { routes = RecentRoute.push(routes, RecentRoute(origin: Station(name: name, lines: []), destination: nil)) }
        XCTAssertEqual(routes.map(\.origin.name), ["한티", "선릉", "강남"])
    }

    func test_문구는_Android와_같다() {
        let ride = ActiveRide(origin: "태평", destination: "야탑",
                              view: RideView(rideId: "r1", status: .atStation, thisStation: "모란", nextStation: "야탑"),
                              online: false, updatedAt: t0, startedAt: t0)
        XCTAssertEqual(RideTexts.title(ride), "이번 역 모란")
        XCTAssertEqual(RideTexts.detail(ride), "정차 중 · 다음 역 야탑 · 연결 끊김(다시 시도 중)")
        XCTAssertEqual(RideTexts.status(ride), "연결 끊김")
    }
}

final class LineSymbolTests: XCTestCase {
    func test_호선은_숫자_그_밖의_노선은_첫_글자() {
        XCTAssertEqual(lineSymbol("2호선"), "2")
        XCTAssertEqual(lineSymbol("9호선"), "9")
        XCTAssertEqual(lineSymbol("수인분당선"), "수")
        XCTAssertEqual(lineSymbol("신분당선"), "신")
    }
}

final class BoardedTimeTests: XCTestCase {
    func test_탑승_시각은_24시간제() {
        let kst = TimeZone(identifier: "Asia/Seoul")!
        let afternoon = ISO8601DateFormatter().date(from: "2026-11-19T04:43:00Z")! // 서울 13:43
        XCTAssertEqual(RideTexts.boardedTime(afternoon, timeZone: kst), "13:43")
    }
}
