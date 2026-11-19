import Foundation

/**
 * 판단 규칙(MotionDetector)이 낸 "출발"을 운영체제의 "탈것 탑승 중" 판단(애플이 학습시킨 Core Motion)이
 * 앞뒤로 확인해 줄 때만 서버에 내보낸다. 기울기·걷기를 출발로 착각한 실기기 오작동(집에서 열차를 탄 것으로 나옴)을 거른다.
 * - 출발 시각은 판단 규칙이 잡은 것을 그대로 쓴다(서버가 열차 출발과 맞추려면 정확해야 함). 운영체제 판단은 늦게 온다.
 * - 확인 안 된 "출발"과 그 뒤의 "도착"은 버린다(서버에는 처음부터 없던 일).
 */
final class VehicleGate {
    /** 출발 [lookBack]초 전부터 [waitAfter]초 뒤까지 "탈것"이었던 적이 있으면 확인된 것. */
    var lookBack: TimeInterval = 30
    var waitAfter: TimeInterval = 120

    /** 운영체제가 "탈것"이라고 한 구간들(끝이 nil이면 아직 탈것). */
    private var spans: [(start: Date, end: Date?)] = []
    /** 확인을 기다리는 움직임(시각 순서). */
    private var pending: [Motion] = []
    /** 마지막으로 내보낸 게 "출발"이었나(그 뒤의 "도착"만 내보낸다). */
    private var released: MotionKind?

    /** 시험용 기록(서버 로그로 보낸다). */
    private(set) var notes: [String] = []

    func onActivity(inVehicle: Bool, at: Date, now: Date) -> [Motion] {
        if inVehicle {
            if spans.last.map({ $0.end != nil }) ?? true { spans.append((at, nil)) }
        } else if let last = spans.last, last.end == nil {
            spans[spans.count - 1].end = at
        }
        note("운영체제 판단 \(inVehicle ? "탈것" : "탈것 아님") \(Self.time(at))")
        return drain(now: now)
    }

    func onMotion(_ motion: Motion, now: Date) -> [Motion] {
        pending.append(motion)
        return drain(now: now)
    }

    /** 확인이 끝내 안 온 "출발"을 버리려고 주기적으로 부른다. */
    func tick(now: Date) -> [Motion] { drain(now: now) }

    func takeNotes() -> [String] {
        defer { notes = [] }
        return notes
    }

    private func drain(now: Date) -> [Motion] {
        var out: [Motion] = []
        while let head = pending.first {
            switch head.kind {
            case .moving:
                if confirmed(head.at) {
                    pending.removeFirst()
                    released = .moving
                    out.append(head)
                } else if now > head.at.addingTimeInterval(waitAfter) {
                    pending.removeFirst()
                    note("확인 안 된 출발 버림 \(Self.time(head.at))")
                } else {
                    return out // 확인을 더 기다린다(뒤의 움직임도 순서대로 기다린다)
                }
            case .stopped:
                pending.removeFirst()
                if released == .moving {
                    released = .stopped
                    out.append(head)
                }
            }
        }
        return out
    }

    private func confirmed(_ at: Date) -> Bool {
        let from = at.addingTimeInterval(-lookBack), to = at.addingTimeInterval(waitAfter)
        return spans.contains { span in span.start <= to && (span.end ?? .distantFuture) >= from }
    }

    private func note(_ text: String) {
        notes.append(text)
        if notes.count > 50 { notes.removeFirst(notes.count - 50) }
    }

    private static func time(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "Asia/Seoul")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: d)
    }
}
