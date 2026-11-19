import ActivityKit
import SwiftUI
import UserNotifications

/** 앱에 하나씩: 서버, 탑승, 탑승 중 돌아가는 것들. 화면 이동 없이 "탑승 중이면 탑승 화면, 아니면 홈". */
@MainActor
final class AppModel {
    let tracker: RideTracker
    let runner: RideRunner
    let home: HomeViewModel
    let probe = SensorDriftProbe()

    init() {
        let api = APIClient()
        tracker = RideTracker(repository: RemoteRideRepository(api: api))
        runner = RideRunner(tracker: tracker, probe: probe)
        home = HomeViewModel(stations: RemoteStationRepository(api: api), tracker: tracker, recentStore: DefaultsRecentRouteStore())
    }
}

@main
struct NowStationApp: App {
    @UIApplicationDelegateAdaptor private var delegate: AppDelegate
    @State private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView(tracker: model.tracker, home: model.home, probe: model.probe)
                .onAppear { model.runner.requestPermissions() }
        }
    }
}

struct RootView: View {
    let tracker: RideTracker
    let home: HomeViewModel
    var probe: SensorDriftProbe?

    var body: some View {
        Group {
            if let ride = tracker.state, ride.choosing {
                TrainPickScreen(
                    ride: ride,
                    load: { try await tracker.trains() },
                    onPick: { try await tracker.choose($0) },
                    onUnsure: { tracker.skipChoosing() },
                    // 아직 안 탔으면 탑승을 없던 일로 하고, 방금 경로를 칸에 다시 채워 둔다(타면 시작만 누르게)
                    onNotYet: {
                        Task {
                            await tracker.end()
                            if let route = home.recent.first { home.useRecent(route) }
                        }
                    }
                )
            } else if let ride = tracker.state {
                RideScreen(ride: ride, probe: probe) { Task { await tracker.end() } }
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

    /**
     * 탑승 중(백그라운드에서 도는 중)에 밀어 닫으면 운영체제가 끝내기 직전에 한 번 부른다.
     * 다이나믹 아일랜드 표시는 앱이 죽어도 남아서(실기기) 여기서 끈다. 곧 죽으므로 끝날 때까지 잠깐(최대 2초) 기다린다.
     */
    func applicationWillTerminate(_ application: UIApplication) {
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            for a in Activity<RideActivityAttributes>.activities {
                await a.end(nil, dismissalPolicy: .immediate)
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + 2)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
