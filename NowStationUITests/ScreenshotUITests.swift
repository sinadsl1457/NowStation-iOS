import XCTest

/**
 * README용 화면: 역 검색(입력 전), 태평 → 야탑을 골라 둔 홈, 탑승 중(세로 노선도에 들어오는 열차), 야탑 도착.
 * 서버는 녹화 재생(2026-11-16 아침, 6073이 태평 → 야탑)이어야 도착까지 찍힌다: 시뮬레이터에는 폰 움직임이 없어 공공 데이터 속도로 간다.
 */
final class ScreenshotUITests: XCTestCase {
    func test_README_화면() {
        let app = XCUIApplication()
        app.launchArguments += ["-skipLaunchIntro"] // 첫 실행 애니메이션 덮개가 첫 탭을 가져가지 않게
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
        let start = app.buttons["탑승 시작"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        snap(app, "readme-home")

        start.tap()
        XCTAssertTrue(app.staticTexts["다음 열차"].waitForExistence(timeout: 20))
        sleep(4) // 열차 점이 조금 내려온 뒤
        snap(app, "readme-riding")

        // 녹화 속 6073이 야탑에 들어서면(약 5분 뒤) 도착
        XCTAssertTrue(app.staticTexts["도착했어요"].waitForExistence(timeout: 420))
        sleep(2) // 파란 화면으로 바뀌는 애니메이션이 끝난 뒤(겹친 화면이 찍혔다)
        snap(app, "readme-alight")
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        let a = XCTAttachment(screenshot: app.screenshot())
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
