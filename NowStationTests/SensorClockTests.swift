import XCTest
@testable import NowStation

final class SensorClockTests: XCTestCase {
    /** 실기기에서 발견: 집에서 시작하고 10분 넘게 걸어가면 탄 열차를 못 찾음. 폰이 잠든 만큼 움직임 시각이 과거로 밀렸다. */
    func test_폰이_잠들었다_깨도_센서_샘플은_실제_시각으로() {
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        // 12분 걷는 동안 폰이 합쳐서 5분 잠듦: 벽시계는 720초, 센서 시계(잠든 동안 멈춤)는 420초 흐름
        let now = start.addingTimeInterval(720)
        let uptime: TimeInterval = 1_000 + 420
        let sample = uptime - 0.05 // 방금(0.05초 전) 잰 값

        let at = SensorClock.wallTime(of: sample, now: now, uptime: uptime)

        XCTAssertEqual(at.timeIntervalSince(now), -0.05, accuracy: 0.01)
    }
}

@MainActor
final class SensorDriftProbeTests: XCTestCase {
    func test_폰이_잠든_시간만큼_이전_방식의_어긋남이_쌓인다() {
        let probe = SensorDriftProbe()
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        probe.begin(now: start, uptime: 1_000)
        // 벽시계 720초, 센서 시계 420초(잠든 300초 동안 멈춤)
        XCTAssertEqual(probe.drift(now: start.addingTimeInterval(720), uptime: 1_420)!, 300, accuracy: 0.001)
        probe.end()
        XCTAssertNil(probe.drift())
    }
}
