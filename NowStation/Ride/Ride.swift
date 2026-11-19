import Foundation

/** 서버가 알려 준 지금 상태. 열차 안 방송처럼 출발한 뒤에는 thisStation이 다가오는 역이다. */
struct RideView: Equatable, Decodable {
    var rideId: String
    var status: RideStatus
    var line: String?
    var thisStation: String?
    var nextStation: String?
    var prepareToAlight: Bool

    enum CodingKeys: String, CodingKey { case rideId, status, line, thisStation, nextStation, prepareToAlight }

    init(rideId: String, status: RideStatus, line: String? = nil, thisStation: String? = nil, nextStation: String? = nil, prepareToAlight: Bool = false) {
        self.rideId = rideId
        self.status = status
        self.line = line
        self.thisStation = thisStation
        self.nextStation = nextStation
        self.prepareToAlight = prepareToAlight
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rideId = try c.decode(String.self, forKey: .rideId)
        status = RideStatus(rawValue: try c.decode(String.self, forKey: .status)) ?? .unknown
        line = try c.decodeIfPresent(String.self, forKey: .line)
        thisStation = try c.decodeIfPresent(String.self, forKey: .thisStation)
        nextStation = try c.decodeIfPresent(String.self, forKey: .nextStation)
        prepareToAlight = try c.decodeIfPresent(Bool.self, forKey: .prepareToAlight) ?? false
    }
}

enum RideStatus: String {
    /** 역에서 열차를 기다림(처음, 열차 놓침, 환승 중) */
    case waiting = "WAITING"
    case atStation = "AT_STATION"
    case moving = "MOVING"
    /** 역 사이(터널)에서 멈춤 */
    case holdingBetween = "HOLDING_BETWEEN"
    /** 탄 열차 소식이 2분 넘게 없음 */
    case stale = "STALE"
    case unknown = "UNKNOWN"
}

enum MotionKind: String, Encodable { case moving = "MOVING", stopped = "STOPPED" }

/** 폰이 느낀 출발·정차. */
struct Motion: Equatable, Encodable {
    var kind: MotionKind
    var at: Date
}

/** 진행 중인 탑승. 서버에 닿지 못하면 마지막 상태를 두고 online만 내린다(지하에서 잠깐 끊겨도 화면이 비지 않게). */
struct ActiveRide: Equatable {
    var origin: String
    var destination: String?
    var view: RideView
    var online: Bool
    var updatedAt: Date
    var unsentMotions: Int = 0
    var startedAt: Date

    /** 내릴 역 알림이 막 켜졌나. 환승 뒤 다시 켜지면 또 울린다. */
    static func alightAlertStarted(before: ActiveRide?, after: ActiveRide?) -> Bool {
        guard let after, after.view.prepareToAlight else { return false }
        guard let before else { return true }
        return !before.view.prepareToAlight || before.view.rideId != after.view.rideId
    }
}

protocol RideRepository {
    func start(origin: String, destination: String?) async throws -> RideView
    func get(rideId: String) async throws -> RideView
    func sendMotion(rideId: String, motions: [Motion], sentAt: Date) async throws -> RideView
    func end(rideId: String) async throws
    /** 시험용 기록(운영체제 판단, 버린 출발)을 서버 로그로. */
    func sendNotes(rideId: String, lines: [String]) async throws
}

/** 서버 탑승 API(README의 API 표와 같은 모양). */
struct RemoteRideRepository: RideRepository {
    let api: APIClient

    private struct StartBody: Encodable { let originStation: String; let destinationStation: String? }
    private struct MotionBody: Encodable { let events: [Motion]; let sentAt: Date }

    func start(origin: String, destination: String?) async throws -> RideView {
        try await api.post("api/rides", body: StartBody(originStation: origin, destinationStation: destination))
    }

    func get(rideId: String) async throws -> RideView {
        try await api.get("api/rides/\(rideId)")
    }

    func sendMotion(rideId: String, motions: [Motion], sentAt: Date) async throws -> RideView {
        try await api.post("api/rides/\(rideId)/motion", body: MotionBody(events: motions, sentAt: sentAt))
    }

    func end(rideId: String) async throws {
        try await api.delete("api/rides/\(rideId)")
    }

    private struct NotesBody: Encodable { let lines: [String] }

    func sendNotes(rideId: String, lines: [String]) async throws {
        try await api.postNoContent("api/rides/\(rideId)/notes", body: NotesBody(lines: lines))
    }
}
