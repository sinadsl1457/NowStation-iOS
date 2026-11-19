import Foundation

/** 서버가 알려 준 지금 상태. 열차 안 방송처럼 출발한 뒤에는 thisStation이 다가오는 역이다. */
struct RideView: Equatable, Decodable {
    var rideId: String
    var status: RideStatus
    var line: String?
    var thisStation: String?
    var nextStation: String?
    var prepareToAlight: Bool
    /** 경로 구간들(태평 ▶ 선릉, 선릉 ▶ 강남). */
    var legs: [RideLeg] = []
    /** 따라가는(골라 둔) 열차 번호. */
    var trainNo: String?
    /** false면 골라 두기만 한 열차(타는 역을 떠날 때 폰과 맞춰 확정). */
    var confirmed = false
    /** 이번 구간 끝(환승역·내릴 역)과 남은 정거장. */
    var target: String?
    var remainingStops: Int?
    /** 놓침·바꿈을 잠깐 알린다. */
    var notice: RideNoticeKind?

    enum CodingKeys: String, CodingKey { case rideId, status, line, thisStation, nextStation, prepareToAlight, legs, trainNo, confirmed, target, remainingStops, notice }

    init(rideId: String, status: RideStatus, line: String? = nil, thisStation: String? = nil, nextStation: String? = nil, prepareToAlight: Bool = false,
         legs: [RideLeg] = [], trainNo: String? = nil, confirmed: Bool = false, target: String? = nil, remainingStops: Int? = nil, notice: RideNoticeKind? = nil) {
        self.rideId = rideId
        self.status = status
        self.line = line
        self.thisStation = thisStation
        self.nextStation = nextStation
        self.prepareToAlight = prepareToAlight
        self.legs = legs
        self.trainNo = trainNo
        self.confirmed = confirmed
        self.target = target
        self.remainingStops = remainingStops
        self.notice = notice
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        rideId = try c.decode(String.self, forKey: .rideId)
        status = RideStatus(rawValue: try c.decode(String.self, forKey: .status)) ?? .unknown
        line = try c.decodeIfPresent(String.self, forKey: .line)
        thisStation = try c.decodeIfPresent(String.self, forKey: .thisStation)
        nextStation = try c.decodeIfPresent(String.self, forKey: .nextStation)
        prepareToAlight = try c.decodeIfPresent(Bool.self, forKey: .prepareToAlight) ?? false
        legs = try c.decodeIfPresent([RideLeg].self, forKey: .legs) ?? []
        trainNo = try c.decodeIfPresent(String.self, forKey: .trainNo)
        confirmed = try c.decodeIfPresent(Bool.self, forKey: .confirmed) ?? false
        target = try c.decodeIfPresent(String.self, forKey: .target)
        remainingStops = try c.decodeIfPresent(Int.self, forKey: .remainingStops)
        notice = try c.decodeIfPresent(String.self, forKey: .notice).flatMap(RideNoticeKind.init(rawValue:))
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

struct RideLeg: Equatable, Decodable, Hashable {
    var line: String
    var from: String
    var to: String
}

/** MISSED: 골라 둔 열차를 놓쳐 다음 열차로 바꿈, SWITCHED: 폰과 같이 출발한 다른 열차로 바꿈. */
enum RideNoticeKind: String { case missed = "MISSED", switched = "SWITCHED" }

/** 가로 노선도: 지금 구간 방향의 역(타는 역 몇 정거장 전부터 구간 끝까지)과 그 위 열차. 이번정거장과 같은 배치. */
struct TrainStrip: Equatable, Decodable {
    var leg: RideLeg
    var stations: [String]
    var boardIndex: Int
    var trains: [StripTrain]
}

struct StripTrain: Equatable, Decodable, Identifiable {
    var trainNo: String
    var station: String
    /** ENTERING(진입)·ARRIVED(도착)·DEPARTED(출발) 등 */
    var status: String
    var terminal: String?
    var selected: Bool
    var seenSecondsAgo: Int
    var id: String { trainNo }
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
    /** 경로가 없으면(내릴 역 없음) nil. */
    func strip(rideId: String) async throws -> TrainStrip?
    func choose(rideId: String, line: String, trainNo: String) async throws -> RideView
    func end(rideId: String) async throws
}

/** 서버 탑승 API(README의 API 표와 같은 모양). */
struct RemoteRideRepository: RideRepository {
    let api: APIClient

    private struct StartBody: Encodable { let originStation: String; let destinationStation: String? }
    private struct MotionBody: Encodable { let events: [Motion]; let sentAt: Date }
    private struct ChooseBody: Encodable { let line: String; let trainNo: String }

    func start(origin: String, destination: String?) async throws -> RideView {
        try await api.post("api/rides", body: StartBody(originStation: origin, destinationStation: destination))
    }

    func get(rideId: String) async throws -> RideView {
        try await api.get("api/rides/\(rideId)")
    }

    func sendMotion(rideId: String, motions: [Motion], sentAt: Date) async throws -> RideView {
        try await api.post("api/rides/\(rideId)/motion", body: MotionBody(events: motions, sentAt: sentAt))
    }

    func strip(rideId: String) async throws -> TrainStrip? {
        try await api.getOptional("api/rides/\(rideId)/trains")
    }

    func choose(rideId: String, line: String, trainNo: String) async throws -> RideView {
        try await api.post("api/rides/\(rideId)/train", body: ChooseBody(line: line, trainNo: trainNo))
    }

    func end(rideId: String) async throws {
        try await api.delete("api/rides/\(rideId)")
    }
}
