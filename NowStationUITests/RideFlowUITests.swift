import XCTest

/** 실제 서버를 상대로 홈 → 역 고르기 → 탑승 시작(다음 열차를 골라 둔 노선도) → 노선도에서 다른 열차 고르기 → 끝내기. 단계마다 화면을 첨부한다. */
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
        app.textFields.firstMatch.typeText("한티")
        XCTAssertTrue(app.staticTexts["한티"].waitForExistence(timeout: 10))
        snap(app, "2-검색")
        app.staticTexts["한티"].firstMatch.tap()
        XCTAssertFalse(app.buttons["탑승 시작"].isEnabled, "내릴 역도 골라야 시작")
        app.staticTexts["고르기"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["내릴 역"].waitForExistence(timeout: 5))
        app.textFields.firstMatch.typeText("강남")
        XCTAssertTrue(app.staticTexts["강남"].waitForExistence(timeout: 10))
        app.staticTexts["강남"].firstMatch.tap()

        let start = app.buttons["탑승 시작"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        snap(app, "3-역-고름")
        start.tap()

        let banner = app.descendants(matching: .any).matching(identifier: "ride-banner").firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 15))
        banner.tap() // 권한 창이 떠 있으면 위 모니터가 처리(노선도의 열차를 누르지 않게 안내 띠를 누른다)
        XCTAssertTrue(app.staticTexts["한티 ▶ 선릉"].exists, "경로 구간: 수인분당선으로 선릉까지")
        XCTAssertTrue(app.staticTexts["선릉 ▶ 강남"].exists, "선릉에서 2호선으로 강남")
        let trains = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'train-'"))
        XCTAssertTrue(trains.firstMatch.waitForExistence(timeout: 15), "노선도에 열차가 보여야 한다")
        XCTAssertTrue((banner.label as String).contains("따라가고 있어요"), "시작하자마자 다음 열차를 골라 따라간다: \(banner.label)")
        snap(app, "4-골라-둔-열차")

        let before = banner.label
        if trains.count > 1 {
            let other = (0..<trains.count).map { trains.element(boundBy: $0) }.first { !before.contains($0.identifier.replacingOccurrences(of: "train-", with: "")) }!
            let no = other.identifier.replacingOccurrences(of: "train-", with: "")
            other.tap()
            let changed = NSPredicate(format: "label CONTAINS %@", no)
            expectation(for: changed, evaluatedWith: banner)
            waitForExpectations(timeout: 15)
            snap(app, "4b-다른-열차-고름")
        }

        app.buttons["탑승 끝내기"].tap()
        XCTAssertTrue(app.alerts["탑승을 끝낼까요?"].waitForExistence(timeout: 5))
        snap(app, "4d-끝내기-확인")
        app.alerts.buttons["계속 타기"].tap()
        XCTAssertTrue(banner.exists, "계속 타면 탑승 화면 그대로")
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
