import SwiftUI
import XCTest
@testable import NowStation

/** 노선이 둘인 역(강남 = 2호선 + 신분당선)이 좁은 폰에서도 칩이 두 줄로 깨지지 않는지 눈으로 확인. */
@MainActor
final class LineChipRenderTests: XCTestCase {
    final class NoStations: StationRepository {
        func search(_ query: String) async throws -> [Station] { [] }
        func lines() async throws -> [String] { [] }
    }

    func test_노선_둘인_역을_좁은_폭에서_그린다() {
        let gangnam = Station(name: "강남", lines: ["2호선", "신분당선"])
        let longName = Station(name: "광교중앙(아주대)", lines: ["신분당선"])
        let vm = HomeViewModel(stations: NoStations(), tracker: RideTracker(repository: FakeRideRepository()), recentStore: MemoryRecentStore())
        // 실기기에서 깨진 조합: 내릴 역(× 버튼이 있어 자리가 더 좁음)에 노선 둘인 강남
        vm.origin = Station(name: "태평", lines: ["수인분당선"])
        vm.destination = gangnam
        for width in [402.0, 375.0, 320.0] {
            attach(HomeRouteCard(vm: vm).padding(.horizontal, 20).frame(width: width).background(Color.ground), "홈-\(Int(width))")
            attach(VStack(spacing: 0) {
                ForEach([gangnam, longName, Station(name: "선릉", lines: ["2호선", "수인분당선"])], id: \.name) {
                    StationRow(station: $0, query: "", chosen: false).padding(.horizontal, 12)
                }
            }.frame(width: width).background(.white), "검색줄-\(Int(width))")
        }
    }

    private func attach(_ view: some View, _ name: String) {
        let r = ImageRenderer(content: view)
        r.scale = 2
        guard let image = r.uiImage else { return XCTFail("그리기 실패") }
        let a = XCTAttachment(image: image)
        a.name = name
        a.lifetime = .keepAlways
        add(a)
    }
}
