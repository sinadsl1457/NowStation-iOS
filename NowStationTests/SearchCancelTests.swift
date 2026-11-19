import XCTest
@testable import NowStation

/** 응답을 주지 않는 가짜 서버(요청이 도는 중에 취소되는 상황을 만든다). */
final class HangingURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {}
    override func stopLoading() {}
}

final class SearchCancelTests: XCTestCase {
    func test_도는_중인_요청을_취소하면_연결_실패가_아니라_취소다() async {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [HangingURLProtocol.self]
        let api = APIClient(baseURL: URL(string: "https://example.test/")!, session: URLSession(configuration: config))
        let task = Task { () -> [String] in try await api.get("api/lines") }
        try? await Task.sleep(nanoseconds: 200_000_000)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("취소됐는데 성공")
        } catch {
            XCTAssertTrue(error is CancellationError, "한글 입력 중 앞 검색을 취소한 것을 '서버에 연결할 수 없어요'로 띄우면 안 된다: \(error)")
        }
    }

    @MainActor
    func test_글자를_이어_치는_동안_앞_검색이_취소돼도_오류를_띄우지_않는다() async {
        final class SlowStations: StationRepository {
            func search(_ query: String) async throws -> [Station] {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 시드니 서버처럼 느린 응답. 취소되면 CancellationError
                return [Station(name: query, lines: [])]
            }
            func lines() async throws -> [String] { [] }
        }
        let vm = HomeViewModel(stations: SlowStations(), tracker: RideTracker(repository: FakeRideRepository()), recentStore: MemoryRecentStore())
        vm.queryChanged("태")
        try? await Task.sleep(nanoseconds: 400_000_000) // "태" 검색이 서버로 간 뒤
        vm.queryChanged("태평")
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        XCTAssertNil(vm.message)
        XCTAssertEqual(vm.results.map(\.name), ["태평"])
    }
}

final class MemoryRecentStore: RecentRouteStore {
    var routes: [RecentRoute] = []
    func load() -> [RecentRoute] { routes }
    func save(_ routes: [RecentRoute]) { self.routes = routes }
}

@MainActor
final class SwapTests: XCTestCase {
    private func vm() -> HomeViewModel {
        HomeViewModel(stations: LineChipRenderTests.NoStations(), tracker: RideTracker(repository: FakeRideRepository()), recentStore: MemoryRecentStore())
    }

    func test_바꾸기를_누르면_타는_역과_내릴_역이_서로_바뀐다() {
        let v = vm()
        XCTAssertFalse(v.canSwap)
        v.origin = Station(name: "태평", lines: ["수인분당선"])
        v.destination = Station(name: "강남", lines: ["2호선", "신분당선"])
        v.swap()
        XCTAssertEqual(v.origin?.name, "강남")
        XCTAssertEqual(v.destination?.name, "태평")
    }

    func test_내릴_역만_골랐을_때_바꾸면_타는_역이_된다() {
        let v = vm()
        v.destination = Station(name: "강남", lines: [])
        XCTAssertTrue(v.canSwap)
        v.swap()
        XCTAssertEqual(v.origin?.name, "강남")
        XCTAssertNil(v.destination)
        XCTAssertFalse(v.canStart, "내릴 역도 골라야 시작")
    }
}

@MainActor
final class SameStationTests: XCTestCase {
    func test_타는_역과_내릴_역이_같으면_시작할_수_없다() async {
        let rides = FakeRideRepository()
        let tracker = RideTracker(repository: rides)
        let v = HomeViewModel(stations: LineChipRenderTests.NoStations(), tracker: tracker, recentStore: MemoryRecentStore())
        v.origin = Station(name: "강남", lines: ["2호선", "신분당선"])
        v.destination = Station(name: "강남", lines: ["2호선", "신분당선"])
        XCTAssertTrue(v.sameStation)
        XCTAssertFalse(v.canStart)
        await v.start()
        XCTAssertNil(tracker.state)
    }
}

@MainActor
final class RequiredDestinationTests: XCTestCase {
    func test_내릴_역을_고르지_않으면_시작할_수_없다() async {
        let tracker = RideTracker(repository: FakeRideRepository())
        let v = HomeViewModel(stations: LineChipRenderTests.NoStations(), tracker: tracker, recentStore: MemoryRecentStore())
        v.origin = Station(name: "태평", lines: ["수인분당선"])
        XCTAssertFalse(v.canStart)
        await v.start()
        XCTAssertNil(tracker.state)
    }

    func test_내릴_역_없이_저장된_옛_최근_경로는_타는_역만_채운다() {
        let tracker = RideTracker(repository: FakeRideRepository())
        let store = MemoryRecentStore()
        store.routes = [RecentRoute(origin: Station(name: "태평", lines: []), destination: nil)]
        let v = HomeViewModel(stations: LineChipRenderTests.NoStations(), tracker: tracker, recentStore: store)
        v.useRecent(v.recent[0])
        XCTAssertNil(tracker.state)
        XCTAssertEqual(v.origin?.name, "태평")
        XCTAssertNil(v.destination)
        XCTAssertFalse(v.canStart)
    }

    func test_최근_경로를_누르면_칸에만_채우고_시작은_사용자가_누른다() async {
        let rides = FakeRideRepository()
        let tracker = RideTracker(repository: rides)
        let store = MemoryRecentStore()
        store.routes = [RecentRoute(origin: Station(name: "태평", lines: []), destination: Station(name: "야탑", lines: []))]
        let v = HomeViewModel(stations: LineChipRenderTests.NoStations(), tracker: tracker, recentStore: store)
        v.useRecent(v.recent[0])
        XCTAssertNil(tracker.state, "바로 시작하지 않는다")
        XCTAssertEqual(v.origin?.name, "태평")
        XCTAssertEqual(v.destination?.name, "야탑")
        v.swap()
        await v.start()
        XCTAssertEqual(tracker.state?.origin, "야탑", "귀갓길: 채운 뒤 바꾸기")
        XCTAssertEqual(tracker.state?.destination, "태평")
    }
}
