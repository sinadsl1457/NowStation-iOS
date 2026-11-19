import Foundation
import Observation

/**
 * 확인용(지울 것): 이전 방식(탑승 시작 때 한 번 잡은 기준)으로 센서 시각을 바꿨다면 지금 몇 초 과거로 찍혔을지.
 * 집에서 시작하고 폰을 잠갔다 켜며 걸으면 이 값이 쌓이는지 실기기로 보려고 탑승 화면에 띄운다.
 */
@MainActor
@Observable
final class SensorDriftProbe {
    private var startWall: Date?
    private var startUptime: TimeInterval = 0

    func begin(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        startWall = now
        startUptime = uptime
    }

    func end() { startWall = nil }

    func drift(now: Date = Date(), uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) -> TimeInterval? {
        guard let startWall else { return nil }
        return now.timeIntervalSince(startWall) - (uptime - startUptime)
    }
}
