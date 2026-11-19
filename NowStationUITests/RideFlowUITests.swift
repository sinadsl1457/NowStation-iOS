import XCTest

/** 실제 서버를 상대로 홈 → 역 고르기 → 탑승 시작 → 탄 열차 고르기(아직 안 탔어요 / 모르겠어요 / 고르기) → 탑승 화면 → 끝내기. 단계마다 화면을 첨부한다. */
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
        app.textFields.firstMatch.typeText("가천대")
        XCTAssertTrue(app.staticTexts["가천대"].waitForExistence(timeout: 10))
        snap(app, "2-검색")
        app.staticTexts["가천대"].firstMatch.tap()
        XCTAssertFalse(app.buttons["탑승 시작"].isEnabled, "내릴 역도 골라야 시작")
        app.staticTexts["고르기"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["내릴 역"].waitForExistence(timeout: 5))
        app.textFields.firstMatch.typeText("선릉")
        XCTAssertTrue(app.staticTexts["선릉"].waitForExistence(timeout: 10))
        app.staticTexts["선릉"].firstMatch.tap()

        let start = app.buttons["탑승 시작"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        snap(app, "3-역-고름")
        start.tap()

        let pickTitle = app.staticTexts["지금 타고 있는 열차를 골라 주세요"]
        XCTAssertTrue(pickTitle.waitForExistence(timeout: 15))
        pickTitle.tap() // 권한 창이 떠 있으면 위 모니터가 처리(목록의 열차를 누르지 않게 제목을 누른다)
        snap(app, "4-열차-고르기")
        app.buttons["아직 안 탔어요"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        XCTAssertTrue(start.isEnabled, "아직 안 탔으면 방금 경로가 칸에 다시 채워져 시작만 누르면 된다")
        snap(app, "4a-아직-안-탔어요")

        start.tap()
        XCTAssertTrue(pickTitle.waitForExistence(timeout: 15))
        app.buttons["목록에 없어요 / 모르겠어요"].tap()
        XCTAssertTrue(app.staticTexts["기다리는 역"].waitForExistence(timeout: 15), "모르겠어요면 지금처럼 폰 움직임으로 찾는다")
        app.buttons["탑승 끝내기"].tap()
        app.alerts.buttons["끝내기"].tap()

        app.staticTexts["가천대 → 선릉"].firstMatch.tap() // 최근 경로로 다시 채움
        start.tap()
        XCTAssertTrue(pickTitle.waitForExistence(timeout: 15))
        let firstTrain = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'train-'")).firstMatch
        XCTAssertTrue(firstTrain.waitForExistence(timeout: 15), "고를 열차가 보여야 한다")
        snap(app, "4b-열차-목록")
        firstTrain.tap()
        XCTAssertTrue(app.staticTexts["이번 역"].waitForExistence(timeout: 15), "고른 열차를 바로 따라간다")
        snap(app, "4c-고른-열차-탑승")
        app.buttons["탑승 끝내기"].tap()
        XCTAssertTrue(app.alerts["탑승을 끝낼까요?"].waitForExistence(timeout: 5))
        snap(app, "4d-끝내기-확인")
        app.alerts.buttons["계속 타기"].tap()
        XCTAssertTrue(app.staticTexts["이번 역"].exists, "계속 타면 탑승 화면 그대로")
        app.buttons["탑승 끝내기"].tap()
        app.alerts.buttons["끝내기"].tap()
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
