import XCTest

/** README용 화면: 태평 → 야탑을 골라 둔 홈, 역 검색(입력 전). 실제 서버를 상대로. */
final class ScreenshotUITests: XCTestCase {
    func test_README_화면() {
        let app = XCUIApplication()
        app.launch()
        app.staticTexts["고르기"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["가천대"].waitForExistence(timeout: 10))
        snap(app, "readme-search")
        app.textFields.firstMatch.typeText("태평")
        let taepyeong = app.buttons.containing(.staticText, identifier: "태평").firstMatch
        XCTAssertTrue(taepyeong.waitForExistence(timeout: 10))
        taepyeong.tap()
        app.staticTexts["고르기"].firstMatch.tap()
        app.textFields.firstMatch.typeText("야탑")
        let yatap = app.buttons.containing(.staticText, identifier: "야탑").firstMatch
        XCTAssertTrue(yatap.waitForExistence(timeout: 10))
        yatap.tap()
        XCTAssertTrue(app.buttons["탑승 시작"].waitForExistence(timeout: 5))
        snap(app, "readme-home")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
