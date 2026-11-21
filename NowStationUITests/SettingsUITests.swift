import XCTest

/** 홈 톱니바퀴 → 설정(알림 스위치) → 문의하기 화면 → 개인정보처리방침 웹뷰 → 라이선스 → 사용법 다시 보기(가이드). 모두 앱 안에서 열린다. */
final class SettingsUITests: XCTestCase {
    func test_설정의_모든_줄이_앱_안에서_열린다() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipLaunchIntro"]
        app.launch()
        app.buttons["설정"].tap()
        for title in ["갈아타기 알림", "내릴 역 알림", "진동", "사용법 다시 보기", "문의하기", "개인정보처리방침", "오픈소스 라이선스", "열차 위치 정보", "버전"] {
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), title)
        }
        snap(app, "settings")

        app.staticTexts["문의하기"].tap()
        XCTAssertTrue(app.staticTexts["답장받을 이메일(선택)"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["보내기"].isEnabled, "내용이 없으면 보낼 수 없다")
        snap(app, "contact")
        app.navigationBars.buttons.firstMatch.tap()

        app.staticTexts["개인정보처리방침"].tap()
        XCTAssertTrue(app.webViews.staticTexts["지금역 개인정보처리방침"].firstMatch.waitForExistence(timeout: 15), "앱 안 웹뷰에 방침이 뜬다")
        snap(app, "privacy")
        app.navigationBars.buttons.firstMatch.tap()

        app.staticTexts["오픈소스 라이선스"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS '외부 오픈소스 라이브러리를 쓰지 않아요'")).firstMatch.waitForExistence(timeout: 5))
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
