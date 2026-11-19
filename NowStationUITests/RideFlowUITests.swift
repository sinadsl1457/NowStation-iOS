import XCTest

/** 실제 서버를 상대로 홈 → 역 고르기 → 탑승 시작 → 탑승 화면 → 끝내기. 단계마다 화면을 첨부한다. */
final class RideFlowUITests: XCTestCase {
    func test_역을_골라_탑승을_시작하고_끝낸다() {
        let app = XCUIApplication()
        app.launch()
        addUIInterruptionMonitor(withDescription: "권한") { alert in
            for label in ["허용", "Allow", "앱을 사용하는 동안 허용", "Allow While Using App"] where alert.buttons[label].exists {
                alert.buttons[label].tap(); return true
            }
            return false
        }
        snap(app, "1-홈")

        app.staticTexts["고르기"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["타는 역"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["가천대"].waitForExistence(timeout: 10) || app.staticTexts["가천대"].waitForExistence(timeout: 1))
        snap(app, "2-검색")
        app.staticTexts["가천대"].firstMatch.tap()

        let start = app.buttons["탑승 시작"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        snap(app, "3-역-고름")
        start.tap()
        app.tap() // 권한 창이 떠 있으면 위 모니터가 처리

        XCTAssertTrue(app.staticTexts["기다리는 역"].waitForExistence(timeout: 15))
        snap(app, "4-탑승")
        app.buttons["탑승 끝내기"].tap()
        XCTAssertTrue(app.staticTexts["최근 경로"].waitForExistence(timeout: 5))
        snap(app, "5-끝내고-홈")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
