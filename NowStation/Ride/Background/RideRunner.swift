import ActivityKit
import AudioToolbox
import CoreLocation
import CoreMotion
import Foundation
import UserNotifications

/**
 * 탑승하는 동안 돌아가는 것들(Android의 포그라운드 서비스 자리).
 * - 앱이 잠들지 않게: 위치 갱신을 켜 둔다(APNs 없이 혼자 쓰는 빌드. 위치 값은 쓰지 않는다)
 * - 가속도 → 출발·정차 사건 → 운영체제의 "탈것 탑승 중" 확인(VehicleGate) → 서버
 * - 5초마다 서버에서 새 상태
 * - 잠금화면·다이나믹 아일랜드(Live Activity), 내릴 역 직전 알림·진동
 */
@MainActor
final class RideRunner: NSObject {
    private let tracker: RideTracker
    private let probe: SensorDriftProbe
    private let location = CLLocationManager()
    private let motion = CMMotionManager()
    private let motionQueue = OperationQueue()
    private var detector = MotionDetector()
    /** 애플이 학습시킨 "걷기/정지/탈것" 판단. 출발이 진짜 탈것인지 확인하는 데 쓴다. */
    private let activityManager = CMMotionActivityManager()
    private var gate = VehicleGate()
    private var refreshTask: Task<Void, Never>?
    private var activity: Activity<RideActivityAttributes>?

    private static let refreshSeconds: UInt64 = 5
    private static let gravity = 9.80665

    init(tracker: RideTracker, probe: SensorDriftProbe) {
        self.tracker = tracker
        self.probe = probe
        super.init()
        motionQueue.maxConcurrentOperationCount = 1
        location.delegate = self
        tracker.onChange = { [weak self] old, new in self?.changed(old, new) }
        clearLeftovers()
    }

    /** 탑승 중에 앱이 죽으면 Live Activity가 운영체제에 남는다. 앱은 탑승을 이어 가지 않으므로 켜질 때 지운다. */
    private func clearLeftovers() {
        for a in Activity<RideActivityAttributes>.activities {
            Task { await a.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /** 처음 시작 전에 한 번: 위치·알림 권한. */
    func requestPermissions() {
        if location.authorizationStatus == .notDetermined { location.requestWhenInUseAuthorization() }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func changed(_ old: ActiveRide?, _ new: ActiveRide?) {
        switch (old, new) {
        case (nil, let ride?): begin(ride)
        case (_?, nil): finish()
        case (_, let ride?):
            let alert = ActiveRide.alightAlertStarted(before: old, after: new)
            updateActivity(ride, alert: alert)
            if alert { alertAlight(ride) }
        default: break
        }
    }

    private func begin(_ ride: ActiveRide) {
        probe.begin()
        keepAwake()
        startMotion()
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: Self.refreshSeconds * 1_000_000_000)
                guard let self else { return }
                await self.release(self.gate.tick(now: Date()))
                await self.tracker.refresh()
                await self.tracker.sendNotes(self.gate.takeNotes())
            }
        }
        startActivity(ride)
    }

    private func finish() {
        probe.end()
        refreshTask?.cancel()
        refreshTask = nil
        motion.stopDeviceMotionUpdates()
        activityManager.stopActivityUpdates()
        letSleep()
        let a = activity
        activity = nil
        Task { await a?.end(nil, dismissalPolicy: .immediate) }
    }

    // MARK: 깨어 있기

    private func keepAwake() {
        location.desiredAccuracy = kCLLocationAccuracyThreeKilometers
        location.distanceFilter = kCLDistanceFilterNone
        location.pausesLocationUpdatesAutomatically = false
        location.allowsBackgroundLocationUpdates = true
        location.showsBackgroundLocationIndicator = true
        location.startUpdatingLocation()
    }

    /** 탑승이 끝나면 위치 갱신과 백그라운드 허용을 함께 끈다. */
    private func letSleep() {
        location.stopUpdatingLocation()
        location.allowsBackgroundLocationUpdates = false
        location.showsBackgroundLocationIndicator = false
    }

    // MARK: 움직임

    /** 운영체제가 확인해 준 움직임만 서버로. */
    private func release(_ motions: [Motion]) async {
        for m in motions { await tracker.report(m) }
    }

    private func startMotion() {
        gate = VehicleGate()
        if CMMotionActivityManager.isActivityAvailable() {
            activityManager.startActivityUpdates(to: .main) { [weak self] a in
                guard let self, let a else { return }
                // 낮은 확신의 "탈것"은 믿지 않는다(첫 시험에서 지하철이 어떻게 나오는지 기록으로 본다)
                let inVehicle = a.automotive && a.confidence != .low
                Task { @MainActor in
                    await self.release(self.gate.onActivity(inVehicle: inVehicle, at: a.startDate, now: Date()))
                    if a.automotive && a.confidence == .low { await self.tracker.sendNotes(["운영체제 판단 탈것(확신 낮음, 안 믿음)"]) }
                }
            }
        }
        // 가속도 + 자이로(회전 빠르기: 사람이 폰을 들거나 내려놓는지 가린다)를 한 번에 받는다
        guard motion.isDeviceMotionAvailable else { return }
        detector = MotionDetector()
        let detector = self.detector
        motion.deviceMotionUpdateInterval = 0.05
        motion.startDeviceMotionUpdates(to: motionQueue) { [weak self] data, _ in
            guard let data else { return }
            let g = Self.gravity
            let at = SensorClock.wallTime(of: data.timestamp, now: Date(), uptime: ProcessInfo.processInfo.systemUptime)
            // 판단 규칙은 중력 포함 가속도를 받는다(Android와 같은 입력)
            let a = (x: data.gravity.x + data.userAcceleration.x, y: data.gravity.y + data.userAcceleration.y, z: data.gravity.z + data.userAcceleration.z)
            let r = data.rotationRate
            let sample = AccelSample(at: at, x: a.x * g, y: a.y * g, z: a.z * g, gyro: Vec(x: r.x, y: r.y, z: r.z))
            guard let event = detector.accept(sample) else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                await self.release(self.gate.onMotion(event, now: Date()))
            }
        }
    }

    // MARK: Live Activity

    private func startActivity(_ ride: ActiveRide) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = RideActivityAttributes(origin: ride.origin, destination: ride.destination)
        activity = try? Activity.request(attributes: attributes,
                                         content: .init(state: RideTexts.activityState(ride), staleDate: nil))
    }

    private func updateActivity(_ ride: ActiveRide, alert: Bool) {
        guard let activity else { return }
        let content = ActivityContent(state: RideTexts.activityState(ride), staleDate: nil)
        Task {
            if alert {
                // 잠금화면이 켜지며 알림처럼 보인다(APNs 없이 앱이 직접 갱신)
                let config = AlertConfiguration(title: "곧 \(ride.view.thisStation ?? "")",
                                                body: "내릴 준비하세요", sound: .default)
                await activity.update(content, alertConfiguration: config)
            } else {
                await activity.update(content)
            }
        }
    }

    // MARK: 내릴 역 알림

    private func alertAlight(_ ride: ActiveRide) {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        let content = UNMutableNotificationContent()
        content.title = RideTexts.title(ride)
        content.body = ride.view.nextStation.map { "다음 역 \($0)" } ?? ""
        content.sound = .default
        let request = UNNotificationRequest(identifier: "alight-\(ride.view.rideId)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

extension RideRunner: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {}
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
