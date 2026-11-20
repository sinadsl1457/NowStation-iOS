import XCTest

/** 처음 실행: 런치 애니메이션 → 가이드 4장(다음으로 넘김) → 마지막 장 버튼에서 권한 → 홈. 장마다 화면을 첨부한다. */
final class GuideUITests: XCTestCase {
    func test_처음_실행하면_가이드를_넘겨_홈으로_간다() {
        let app = XCUIApplication()
        app.launchArguments += ["-guide_seen_v1", "NO"] // 이미 봤어도 이번 실행은 처음처럼(UserDefaults 인자)
        app.launch()
        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["허용", "Allow", "앱을 사용하는 동안 허용", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
        let titles = ["타는 역·내릴 역만 고르세요", "탈 열차를 눌러요", "탔으면 폰은 넣어 두세요", "한 정거장 전에 깨워 드려요"]
        for (i, title) in titles.enumerated() {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 8), "\(i + 1)장: \(title)")
            sleep(2) // 그림이 한 번 움직인 뒤
            snap(app, "guide-\(i + 1)")
            if i < titles.count - 1 { app.buttons["다음"].tap() }
        }
        XCTAssertFalse(app.buttons["건너뛰기"].exists, "마지막 장에는 건너뛰기가 없다")
        app.buttons["알림 허용하고 시작하기"].tap()
        sleep(2)
        app.tap() // 권한 창이 떠 있으면 위 모니터가 처리
        XCTAssertTrue(app.buttons["탑승 시작"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.staticTexts[titles[3]].exists, "가이드가 닫혔다")
        snap(app, "guide-home")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
