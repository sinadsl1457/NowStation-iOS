import Foundation

/**
 * 센서 시각(부팅 뒤 초)을 벽시계로. 센서 시계는 폰이 잠든 동안 멈추므로 시작 때 한 번 잡은 기준을 계속 쓰면
 * 잠든 만큼 과거로 밀린다(집에서 시작해 걸어가면 열차 출발 움직임이 몇 분 전으로 찍혀 탄 열차를 못 찾음).
 * 그래서 샘플마다 "지금으로부터 얼마나 전에 잰 값인가"로 바꾼다(Android Accelerometer와 같은 방식).
 */
enum SensorClock {
    static func wallTime(of sampleUptime: TimeInterval, now: Date, uptime: TimeInterval) -> Date {
        now.addingTimeInterval(sampleUptime - uptime)
    }
}
