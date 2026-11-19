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
