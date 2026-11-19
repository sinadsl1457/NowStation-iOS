import SwiftUI
import UserNotifications

/** 앱에 하나씩: 서버, 탑승, 탑승 중 돌아가는 것들. 화면 이동 없이 "탑승 중이면 탑승 화면, 아니면 홈". */
@MainActor
final class AppModel {
    let tracker: RideTracker
    let runner: RideRunner
    let home: HomeViewModel

    init() {
        let api = APIClient()
        tracker = RideTracker(repository: RemoteRideRepository(api: api))
        runner = RideRunner(tracker: tracker)
        home = HomeViewModel(stations: RemoteStationRepository(api: api), tracker: tracker, recentStore: DefaultsRecentRouteStore())
    }
}

@main
struct NowStationApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(tracker: model.tracker, home: model.home)
                .onAppear { model.runner.requestPermissions() }
        }
    }
}

struct RootView: View {
    let tracker: RideTracker
    let home: HomeViewModel

    var body: some View {
        Group {
            if let ride = tracker.state {
                RideScreen(ride: ride) { Task { await tracker.end() } }
            } else {
                HomeView(vm: home)
            }
        }
        // 파란 화면(홈 머리 영역, 내릴 준비)에서는 상태 표시줄 글자를 흰색으로. 화면 색은 모두 직접 정해 두었다
        .preferredColorScheme(tracker.state.map { $0.view.prepareToAlight ? .dark : .light } ?? .dark)
        .alert("탑승 정보를 잃었어요", isPresented: Binding(get: { tracker.lostNotice }, set: { tracker.lostNotice = $0 })) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("서버가 다시 시작돼 탑승을 이어 갈 수 없어요. 다시 시작해 주세요.")
        }
    }
}

/** 앱을 보고 있을 때도 내릴 역 알림이 배너·소리로 뜨게. */
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
