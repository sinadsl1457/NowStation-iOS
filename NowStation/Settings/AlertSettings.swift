import Foundation

/** 앱 안 알림 스위치(Android와 같은 셋). 잠금화면·다이나믹 아일랜드의 현재역 표시는 탑승을 끝내면 사라진다. */
struct AlertPrefs: Equatable {
    /** 갈아탈 역 한 정거장 전 알림. */
    var transfer = true
    /** 내릴 역 한 정거장 전 알림. */
    var alight = true
    /** 위 알림 때 진동. */
    var vibrate = true

    func allows(transfer isTransfer: Bool) -> Bool { isTransfer ? transfer : alight }
}

enum AlertSettings {
    private static let defaults = UserDefaults.standard

    static var current: AlertPrefs {
        get {
            AlertPrefs(
                transfer: defaults.object(forKey: "alert_transfer") as? Bool ?? true,
                alight: defaults.object(forKey: "alert_alight") as? Bool ?? true,
                vibrate: defaults.object(forKey: "alert_vibrate") as? Bool ?? true
            )
        }
        set {
            defaults.set(newValue.transfer, forKey: "alert_transfer")
            defaults.set(newValue.alight, forKey: "alert_alight")
            defaults.set(newValue.vibrate, forKey: "alert_vibrate")
        }
    }
}
