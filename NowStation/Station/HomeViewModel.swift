import Foundation
import Observation

/** 지금 고르는 칸: 출발역(필수) 또는 내릴 역(선택). */
enum PickTarget { case origin, destination }

/** 홈: 역을 검색해 출발역(과 내릴 역)을 고르고 탑승을 시작한다. Android HomeViewModel과 같은 흐름. */
@MainActor
@Observable
final class HomeViewModel {
    var target: PickTarget = .origin
    var searching = false
    var query = ""
    private(set) var results: [Station] = []
    var origin: Station?
    var destination: Station?
    private(set) var recent: [RecentRoute] = []
    /** 지원 노선. 받아 오지 못하면 비워 두고 홈에서 그 칸을 숨긴다. */
    private(set) var lines: [String] = []
    private(set) var isStarting = false
    var message: String?

    var canStart: Bool { origin != nil && !isStarting }

    @ObservationIgnored private let stations: StationRepository
    @ObservationIgnored private let tracker: RideTracker
    @ObservationIgnored private let recentStore: RecentRouteStore
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /** 탑승 시작에 성공하면(권한 요청 등). */
    @ObservationIgnored var onStarted: (() -> Void)?

    init(stations: StationRepository, tracker: RideTracker, recentStore: RecentRouteStore) {
        self.stations = stations
        self.tracker = tracker
        self.recentStore = recentStore
        recent = recentStore.load()
    }

    func load() async {
        await search("")
        if let l = try? await stations.lines() { lines = l }
    }

    /** 입력이 잠깐 멈추면 찾는다(글자마다 서버를 부르지 않게). */
    func queryChanged(_ q: String) {
        query = q
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            if Task.isCancelled { return }
            await search(q)
        }
    }

    /** 고르면 검색을 닫고 홈으로. 내릴 역은 선택이라 자동으로 열지 않는다. */
    func pick(_ station: Station) {
        switch target {
        case .origin: origin = station
        case .destination: destination = station
        }
        closeSearch()
    }

    func edit(_ t: PickTarget) {
        target = t
        query = ""
        searching = true
        Task { await search("") }
    }

    func closeSearch() {
        query = ""
        searching = false
        Task { await search("") }
    }

    func clearDestination() { destination = nil }

    func startRecent(_ route: RecentRoute) async {
        guard !isStarting else { return }
        origin = route.origin
        destination = route.destination
        await start()
    }

    func start() async {
        guard let origin, !isStarting else { return }
        isStarting = true
        defer { isStarting = false }
        do {
            try await tracker.start(origin: origin.name, destination: destination?.name)
            recent = RecentRoute.push(recent, RecentRoute(origin: origin, destination: destination))
            recentStore.save(recent)
            self.origin = nil
            self.destination = nil
            onStarted?()
        } catch {
            message = Self.message(of: error)
        }
    }

    private func search(_ q: String) async {
        do {
            let found = try await stations.search(q.trimmingCharacters(in: .whitespaces))
            if query.trimmingCharacters(in: .whitespaces) == q.trimmingCharacters(in: .whitespaces) { results = found }
        } catch {
            message = Self.message(of: error)
        }
    }

    static func message(of error: Error) -> String {
        switch error as? APIError {
        case .network: return "서버에 연결할 수 없어요"
        case .badRequest: return "모르는 역이에요"
        default: return "잠시 후 다시 시도해 주세요"
        }
    }
}
