import XCTest
@testable import NowStation

/**
 * Android MotionDetectorTest와 같은 합성 신호(20Hz, 폰은 세로, 중력 9.8은 y, 열차 진행은 x).
 * 실제 지하철 값이 아니므로 기준값(MotionRules)은 실기기에서 다시 맞춘다.
 */
final class MotionDetectorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private var rng = SystemRandomNumberGenerator()

    private func noise() -> Double { (Double.random(in: 0..<1, using: &rng) - 0.5) * 0.1 }

    private func signal(_ from: Double, _ to: Double,
                        accel: (Double) -> Double = { _ in 0 },
                        extra: (Double) -> (Double, Double, Double) = { _ in (0, 0, 0) }) -> [AccelSample] {
        stride(from: from, to: to, by: 0.05).map { s in
            let (ex, ey, ez) = extra(s)
            return AccelSample(at: t0.addingTimeInterval(s), x: accel(s) + ex + noise(), y: 9.8 + ey + noise(), z: ez + noise())
        }
    }

    private func run(_ samples: [AccelSample]) -> [Motion] {
        let d = MotionDetector()
        return samples.compactMap { d.accept($0) }
    }

    private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    /** 한 정거장: 10~20초 출발 가속, 70~80초 감속. */
    private let oneStop: (Double) -> Double = { s in
        if (10...20).contains(s) { return 0.9 }
        if (70...80).contains(s) { return -0.9 }
        return 0
    }

    func test_가만히_있으면_아무_일도_없다() {
        XCTAssertTrue(run(signal(0, 60)).isEmpty)
    }

    func test_출발은_가속_시작_시각으로_반대_방향_감속은_끝난_시각으로() {
        let events = run(signal(0, 100, accel: oneStop))
        XCTAssertEqual(events.map(\.kind), [.moving, .stopped])
        XCTAssertEqual(events[0].at.timeIntervalSince(at(10)), 0, accuracy: 1.5)
        XCTAssertEqual(events[1].at.timeIntervalSince(at(80)), 0, accuracy: 1.5)
    }

    func test_두_정거장_연속() {
        let twoStops: (Double) -> Double = { s in
            switch s {
            case 10...20, 100...110: return 0.9
            case 60...70, 150...160: return -0.9
            default: return 0
            }
        }
        XCTAssertEqual(run(signal(0, 180, accel: twoStops)).map(\.kind), [.moving, .stopped, .moving, .stopped])
    }

    func test_걷는_흔들림은_출발로_보지_않는다() {
        let walking = signal(0, 60, extra: { s in (0, 2 * sin(2 * .pi * 2 * s), cos(2 * .pi * 2 * s)) })
        XCTAssertTrue(run(walking).isEmpty)
    }

    func test_2초짜리_짧은_밀림은_출발이_아니다() {
        XCTAssertTrue(run(signal(0, 40, accel: { (10...12).contains($0) ? 0.9 : 0 })).isEmpty)
    }

    func test_폰을_돌려_중력_방향이_바뀌면_출발로_보지_않는다() {
        let samples = signal(0, 60).map { s -> AccelSample in
            guard s.at >= at(20) else { return s }
            var t = s; t.x += 9.8; t.y -= 9.8; return t
        }
        XCTAssertTrue(run(samples).isEmpty)
    }

    func test_달리는_중_같은_방향_가속은_도착이_아니다() {
        let events = run(signal(0, 120, accel: { (10...20).contains($0) || (50...58).contains($0) ? 0.9 : 0 }))
        XCTAssertEqual(events.map(\.kind), [.moving])
    }
}

/** 실기기에서 발견: 탑승을 시작하고 폰을 책상에 내려놓았더니 가만히 있는데 "출발"로 판단해 엉뚱한 열차를 따라감. */
final class TiltTests: XCTestCase {
    func test_손에_들었다가_조금_기울여_책상에_내려놓으면_출발이_아니다() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let d = MotionDetector()
        var events: [Motion] = []
        let g = 9.8
        for i in 0..<(120 * 20) {
            let s = Double(i) * 0.05
            let tilt: Double
            var shake = 0.0
            switch s {
            case ..<10: tilt = 0                                   // 손에 들고 화면 보는 중
            case 10..<11.5: tilt = (s - 10) / 1.5 * 8; shake = 1.5 * sin(2 * .pi * 6 * s) // 내려놓는 동작(1.5초, 덜컹)
            default: tilt = 8                                      // 책상 위, 처음보다 8도 기울어 가만히
            }
            let r = tilt * .pi / 180
            let sample = AccelSample(at: t0.addingTimeInterval(s), x: g * sin(r) + shake, y: g * cos(r), z: shake * 0.5)
            if let e = d.accept(sample) { events.append(e) }
        }
        XCTAssertTrue(events.isEmpty, "가만히 있는데 \(events)")
    }

    func test_흔들림_없이_살살_돌려_내려놓아도_자이로로_따라가_출발이_아니다() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let d = MotionDetector()
        var events: [Motion] = []
        for i in 0..<(90 * 20) {
            let s = Double(i) * 0.05
            let deg = s < 10 ? 0 : s < 11 ? (s - 10) * 10 : 10.0     // 1초에 10° 돌려 내려놓음(0.17 rad/s 아님: 아래 회전값)
            let rot = (10..<11).contains(s) ? 10 * Double.pi / 180 : 0.0 // 자이로: 실제로 돈 빠르기(1초에 10°)
            let r = deg * .pi / 180
            if let e = d.accept(AccelSample(at: t0.addingTimeInterval(s), x: 9.8 * sin(r), y: 9.8 * cos(r), z: 0, gyro: Vec(x: 0, y: 0, z: rot))) { events.append(e) }
        }
        XCTAssertTrue(events.isEmpty, "가만히 있는데 \(events)")
    }

    func test_천천히_기울어_굳어도_40초_뒤에는_풀리고_진짜_출발을_잡는다() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let d = MotionDetector()
        var events: [Motion] = []
        for i in 0..<(200 * 20) {
            let s = Double(i) * 0.05
            let deg = s < 10 ? 0 : s < 20 ? (s - 10) * 0.6 : 6.0      // 회전·흔들림 없이 10초에 걸쳐 6° 기울어짐
            let r = deg * .pi / 180
            let train = (150...160).contains(s) ? 0.9 : 0                // 150초에 진짜 출발
            if let e = d.accept(AccelSample(at: t0.addingTimeInterval(s), x: 9.8 * sin(r), y: 9.8 * cos(r), z: train)) { events.append(e) }
        }
        XCTAssertEqual(events.last?.kind, .moving)
        XCTAssertEqual(events.last!.at.timeIntervalSince(t0.addingTimeInterval(150)), 0, accuracy: 1.5, "진짜 출발을 놓치지 않는다")
    }

    /** 실기기에서 발견(두 번째): 폰을 쥐고 집 안을 걸으며 손 각도가 천천히 바뀌자 "출발"로 판단. */
    func test_폰을_들고_걸으며_손_각도가_천천히_바뀌어도_출발이_아니다() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let d = MotionDetector()
        var events: [Motion] = []
        let period = 20.0, amp = 12.0 // 20초마다 ±12° 천천히 오락가락(최대 초당 약 4°, 만진다고 보기엔 느림)
        for i in 0..<(180 * 20) {
            let s = Double(i) * 0.05
            let deg = amp * sin(2 * .pi * s / period)
            let rate = amp * (2 * .pi / period) * cos(2 * .pi * s / period) * .pi / 180
            let step = 0.3 * sin(2 * .pi * 1.8 * s) // 살살 걷는 덜컹(판단을 막을 만큼 크지 않음)
            let r = deg * .pi / 180
            if let e = d.accept(AccelSample(at: t0.addingTimeInterval(s), x: 9.8 * sin(r), y: 9.8 * cos(r) + step, z: 0, gyro: Vec(x: 0, y: 0, z: rate))) { events.append(e) }
        }
        XCTAssertTrue(events.isEmpty, "들고 걷기만 했는데 \(events)")
    }

    func test_가만히_있는데_자이로가_조금씩_틀려도_10분_동안_출발이_아니다() {
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        let d = MotionDetector()
        var events: [Motion] = []
        for i in 0..<(600 * 20) {
            let s = Double(i) * 0.05
            // 센서 오차: 실제로는 안 도는데 0.015 rad/s(초당 약 0.9°)씩 돈다고 나옴
            if let e = d.accept(AccelSample(at: t0.addingTimeInterval(s), x: 0, y: 9.8, z: 0, gyro: Vec(x: 0, y: 0, z: 0.015))) { events.append(e) }
        }
        XCTAssertTrue(events.isEmpty, "책상 위인데 \(events)")
    }
}
