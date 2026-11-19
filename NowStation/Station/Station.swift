import Foundation

/** 역 이름과 지나는 노선(표시 이름: 2호선, 수인분당선). */
struct Station: Equatable, Hashable, Codable {
    var name: String
    var lines: [String]
}

protocol StationRepository {
    func search(_ query: String) async throws -> [Station]
    func lines() async throws -> [String]
}

struct RemoteStationRepository: StationRepository {
    let api: APIClient

    func search(_ query: String) async throws -> [Station] {
        try await api.get("api/stations", query: [URLQueryItem(name: "query", value: query)])
    }

    func lines() async throws -> [String] {
        try await api.get("api/lines")
    }
}

/** 탑승을 시작한 경로. 폰 안에만 최대 3개. */
struct RecentRoute: Equatable, Codable {
    var origin: Station
    var destination: Station?

    static let max = 3

    /** 맨 앞에 넣고, 같은 경로(역 이름 기준)는 하나만 남긴다. */
    static func push(_ routes: [RecentRoute], _ route: RecentRoute) -> [RecentRoute] {
        let rest = routes.filter { $0.origin.name != route.origin.name || $0.destination?.name != route.destination?.name }
        return Array(([route] + rest).prefix(max))
    }
}

protocol RecentRouteStore {
    func load() -> [RecentRoute]
    func save(_ routes: [RecentRoute])
}

/** 한 키에 목록 전체를 JSON으로(반쪽 저장 방지). Android와 같은 키 이름. */
struct DefaultsRecentRouteStore: RecentRouteStore {
    var defaults: UserDefaults = .standard
    private let key = "recent_routes_v1"

    func load() -> [RecentRoute] {
        guard let data = defaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([RecentRoute].self, from: data)) ?? []
    }

    func save(_ routes: [RecentRoute]) {
        defaults.set(try? JSONEncoder().encode(routes), forKey: key)
    }
}
