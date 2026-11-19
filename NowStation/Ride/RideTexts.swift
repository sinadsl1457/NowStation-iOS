import Foundation

/** 화면과 잠금화면(Live Activity)이 같은 문구를 쓰도록 한곳에 둔다. Android RideTexts와 같은 문구. */
enum RideTexts {
    static func title(_ ride: ActiveRide) -> String {
        let v = ride.view
        if v.prepareToAlight, let s = v.thisStation { return isTransfer(ride) ? "곧 \(s), 갈아탈 준비하세요" : "곧 \(s), 내릴 준비하세요" }
        if v.status == .waiting { return "\(v.thisStation ?? ride.origin)역에서 기다리는 중" }
        if v.status == .stale || v.thisStation == nil { return "위치 확인 중" }
        return "이번 역 \(v.thisStation!)"
    }

    /** 다이나믹 아일랜드처럼 몇 글자만 보이는 곳. 열차 소식이 없으면 틀린 역을 붙여 두지 않게 비운다. */
    static func chip(_ ride: ActiveRide) -> String? {
        switch ride.view.status {
        case .waiting: return "대기"
        case .atStation, .moving, .holdingBetween: return ride.view.thisStation
        case .stale, .unknown: return nil
        }
    }

    static func detail(_ ride: ActiveRide) -> String {
        let v = ride.view
        let main: String
        switch v.status {
        case .waiting: main = "열차에 타면 자동으로 따라가요"
        case .atStation: main = ["정차 중", v.nextStation.map { "다음 역 \($0)" }].compactMap { $0 }.joined(separator: " · ")
        case .moving: main = v.nextStation.map { "다음 역 \($0)" } ?? "종점 방면"
        case .holdingBetween: main = "역 사이에서 잠시 정차 중"
        case .stale: main = v.thisStation.map { "마지막으로 확인한 역 \($0)" } ?? "열차 소식을 기다리는 중"
        case .unknown: main = "상태를 확인하는 중"
        }
        return ride.online ? main : "\(main) · 연결 끊김(다시 시도 중)"
    }

    /** 탑승 화면 위쪽 상태 표시. 연결이 끊기면 그게 먼저다(보이는 역이 오래된 것일 수 있음). */
    static func status(_ ride: ActiveRide) -> String {
        if !ride.online { return "연결 끊김" }
        switch ride.view.status {
        case .waiting: return "기다리는 중"
        case .atStation: return "정차 중"
        case .moving: return "달리는 중"
        case .holdingBetween: return "역 사이 정차"
        case .stale, .unknown: return "위치 확인 중"
        }
    }

    /** "선릉까지 6정거장". 구간 끝(환승역·내릴 역)까지. 모르면 nil. */
    static func remaining(_ ride: ActiveRide) -> String? {
        guard let target = ride.view.target, let n = ride.view.remainingStops else { return nil }
        return n == 0 ? "이번 역이 \(target)이에요" : "\(target)까지 \(n)정거장"
    }

    /** 노선도 위 열차 이름표: "왕십리행". */
    static func terminal(_ t: StripTrain) -> String { t.terminal.map { "\($0)행" } ?? "" }

    /** 이번 구간 끝이 갈아탈 역인가(내릴 역이 아니라). */
    static func isTransfer(_ ride: ActiveRide) -> Bool {
        guard let target = ride.view.target, let destination = ride.destination else { return false }
        return target != destination
    }

    /** 화면 위 안내 띠: 따라가는 열차, 환승역 도착. 고른 열차는 그대로 따라간다(탔으면 가는 것). */
    static func banner(_ ride: ActiveRide) -> String {
        let v = ride.view
        guard let no = v.trainNo else { return "탄 열차를 아래 노선도에서 골라 주세요" }
        if v.notice == .transfer {
            let line = v.line ?? ""
            return "갈아타세요: \(line) \(v.target ?? "") 방면 \(no) 열차를 골라 뒀어요. 다른 열차면 아래에서 눌러 주세요"
        }
        return "\(no) 열차를 따라가고 있어요. 다른 열차면 아래에서 눌러 주세요"
    }

    /** "13:43 탑승"의 시각. 24시간제(오후 1시가 "01:43"으로 보이던 문제), Android와 같게. */
    static func boardedTime(_ date: Date, timeZone: TimeZone = .current) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    static func activityState(_ ride: ActiveRide) -> RideActivityAttributes.ContentState {
        .init(title: title(ride), detail: remaining(ride) ?? detail(ride), chip: chip(ride), line: ride.view.line,
              prepareToAlight: ride.view.prepareToAlight, online: ride.online, remaining: ride.view.remainingStops)
    }
}
