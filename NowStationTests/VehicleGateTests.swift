import XCTest
@testable import NowStation

final class VehicleGateTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func at(_ s: Double) -> Date { t0.addingTimeInterval(s) }

    func test_운영체제가_탈것이라고_하기_전까지_출발을_들고_있다가_확인되면_원래_시각으로_보낸다() {
        let gate = VehicleGate()
        XCTAssertEqual(gate.onMotion(Motion(kind: .moving, at: at(30)), now: at(30)), [])
        XCTAssertEqual(gate.tick(now: at(60)), [])
        // 운영체제는 늦게 안다: 40초에 탈것이 시작됐다고 70초에 알려 줌
        XCTAssertEqual(gate.onActivity(inVehicle: true, at: at(40), now: at(70)), [Motion(kind: .moving, at: at(30))])
    }

    func test_책상_위_기울기처럼_운영체제가_탈것이라고_안_하면_출발을_버린다() {
        let gate = VehicleGate()
        _ = gate.onMotion(Motion(kind: .moving, at: at(30)), now: at(30))
        _ = gate.onActivity(inVehicle: false, at: at(0), now: at(40))
        XCTAssertEqual(gate.tick(now: at(151)), [])
        XCTAssertTrue(gate.takeNotes().contains { $0.contains("확인 안 된 출발 버림") })
        // 버린 출발 뒤의 도착도 내보내지 않는다(서버에는 처음부터 없던 일)
        XCTAssertEqual(gate.onMotion(Motion(kind: .stopped, at: at(200)), now: at(200)), [])
    }

    func test_이미_탈것인_동안의_출발과_도착은_바로_보낸다() {
        let gate = VehicleGate()
        _ = gate.onActivity(inVehicle: true, at: at(0), now: at(5))
        XCTAssertEqual(gate.onMotion(Motion(kind: .moving, at: at(30)), now: at(30)), [Motion(kind: .moving, at: at(30))])
        XCTAssertEqual(gate.onMotion(Motion(kind: .stopped, at: at(90)), now: at(90)), [Motion(kind: .stopped, at: at(90))])
    }

    func test_확인을_기다리는_동안_온_도착은_출발이_확인되면_순서대로_같이_보낸다() {
        let gate = VehicleGate()
        _ = gate.onMotion(Motion(kind: .moving, at: at(30)), now: at(30))
        XCTAssertEqual(gate.onMotion(Motion(kind: .stopped, at: at(80)), now: at(80)), [])
        XCTAssertEqual(gate.onActivity(inVehicle: true, at: at(35), now: at(100)),
                       [Motion(kind: .moving, at: at(30)), Motion(kind: .stopped, at: at(80))])
    }

    func test_탈것에서_내린_뒤_한참_지나_생긴_출발은_예전_탈것_구간으로_확인하지_않는다() {
        let gate = VehicleGate()
        _ = gate.onActivity(inVehicle: true, at: at(0), now: at(0))
        _ = gate.onActivity(inVehicle: false, at: at(100), now: at(100))
        _ = gate.onMotion(Motion(kind: .moving, at: at(400)), now: at(400))
        XCTAssertEqual(gate.tick(now: at(521)), [])
    }
}
