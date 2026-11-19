import SwiftUI
import XCTest
@testable import NowStation

/** 실제 열차 없이는 볼 수 없는 화면을 그려서 첨부한다(눈으로 확인용). */
@MainActor
final class RideScreenRenderTests: XCTestCase {
    func test_탑승_중과_내릴_준비_화면을_그린다() throws {
        let t = Date()
        var ride = ActiveRide(origin: "태평", destination: "야탑",
                              view: RideView(rideId: "r1", status: .moving, line: "수인분당선", thisStation: "모란", nextStation: "야탑"),
                              online: true, updatedAt: t, startedAt: t)
        attach(RideScreen(ride: ride) {}, "탑승-중")
        ride.view = RideView(rideId: "r1", status: .moving, line: "수인분당선", thisStation: "야탑", nextStation: "이매", prepareToAlight: true)
        attach(RideScreen(ride: ride) {}, "내릴-준비")
    }

    private func attach(_ view: some View, _ name: String) {
        let renderer = ImageRenderer(content: view.frame(width: 393, height: 852))
        renderer.scale = 2
        guard let image = renderer.uiImage else { return XCTFail("그리기 실패") }
        let a = XCTAttachment(image: image)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
