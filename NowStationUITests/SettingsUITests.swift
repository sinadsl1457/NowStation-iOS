import XCTest

/** 홈 톱니바퀴 → 설정의 줄들 → 오픈소스 라이선스 → 사용법 다시 보기(가이드가 열림). */
final class SettingsUITests: XCTestCase {
    func test_설정에서_라이선스와_사용법을_연다() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipLaunchIntro"]
        app.launch()
        app.buttons["설정"].tap()
        for title in ["알림 설정", "사용법 다시 보기", "문의하기", "개인정보처리방침", "오픈소스 라이선스", "열차 위치 정보", "버전"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), title)
        }
        snap(app, "settings")
        app.staticTexts["오픈소스 라이선스"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '외부 오픈소스 라이브러리를 쓰지 않아요'")).firstMatch.waitForExistence(timeout: 5))
        snap(app, "licenses")
        app.navigationBars.buttons.firstMatch.tap()
        app.staticTexts["사용법 다시 보기"].tap()
        XCTAssertTrue(app.staticTexts["타는 역·내릴 역만 고르세요"].waitForExistence(timeout: 5), "설정을 닫고 가이드가 열린다")
        app.buttons["건너뛰기"].tap()
        XCTAssertTrue(app.buttons["탑승 시작"].waitForExistence(timeout: 5))
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
