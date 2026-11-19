import Foundation
import Observation

/**
 * 진행 중인 탑승 하나를 앱 전체(화면, Live Activity, 백그라운드 갱신)가 같이 본다.
 * 화면이 사라져도 탑승은 계속돼야 해서 화면이 아니라 여기(앱에 하나)가 갖는다. Android RideTracker와 같은 규칙.
 */
@MainActor
@Observable
final class RideTracker {
    private(set) var state: ActiveRide?
    /** 서버에서 탑승이 사라짐(서버 재시작 등). 화면이 한 번 알리고 지운다. */
    var lostNotice = false

    @ObservationIgnored private let repository: RideRepository
    @ObservationIgnored private let now: () -> Date
    /** 보낼 움직임. 지하에서 끊기면 쌓였다가 다음에 한꺼번에 간다(서버는 늦게 온 움직임도 시각대로 판단한다). */
    @ObservationIgnored private var pending: [Motion] = []
    /** 갱신 반복과 센서가 동시에 보내도 같은 움직임을 두 번 보내지 않게 한 번에 하나씩. */
    @ObservationIgnored private var syncing = false
    @ObservationIgnored private var syncAgain = false

    /** 상태가 바뀔 때마다(Live Activity·알림이 따라간다). */
    @ObservationIgnored var onChange: ((ActiveRide?, ActiveRide?) -> Void)?

    private static let maxPending = 50

    init(repository: RideRepository, now: @escaping () -> Date = Date.init) {
        self.repository = repository
        self.now = now
    }

    func start(origin: String, destination: String?) async throws {
        let view = try await repository.start(origin: origin, destination: destination)
        pending = []
        let t = now()
        set(ActiveRide(origin: origin, destination: destination, view: view, online: true, updatedAt: t, startedAt: t))
    }

    /** 가로 노선도. 탑승 화면이 15초마다 부른다. */
    func strip() async throws -> TrainStrip? {
        guard let ride = state else { return nil }
        return try await repository.strip(rideId: ride.view.rideId)
    }

    /** 노선도에서 다른 열차를 고른다(골라 둔 열차가 틀렸을 때). */
    func choose(_ train: StripTrain, line: String) async throws {
        guard let ride = state else { return }
        let view = try await repository.choose(rideId: ride.view.rideId, line: line, trainNo: train.trainNo)
        guard var current = state, current.view.rideId == ride.view.rideId else { return }
        current.view = view
        current.online = true
        current.updatedAt = now()
        set(current)
    }

    /** 몇 초마다 부른다. 못 보낸 움직임이 있으면 그것부터 보낸다. */
    func refresh() async { await sync() }

    func report(_ motion: Motion) async {
        guard state != nil else { return }
        pending = Array((pending + [motion]).suffix(Self.maxPending))
        state?.unsentMotions = pending.count
        await sync()
    }

    /** 끝내기. 서버에 못 알려도 앱에서는 끝낸다. */
    func end() async {
        guard let ride = state else { return }
        set(nil)
        pending = []
        try? await repository.end(rideId: ride.view.rideId)
    }

    private func sync() async {
        if syncing { syncAgain = true; return }
        syncing = true
        defer { syncing = false }
        repeat {
            syncAgain = false
            await syncOnce()
        } while syncAgain
    }

    private func syncOnce() async {
        guard let ride = state else { return }
        let batch = pending
        do {
            let view = batch.isEmpty
                ? try await repository.get(rideId: ride.view.rideId)
                // 보낸 시각을 같이 보내 서버가 폰 시계 차이를 맞춘다
                : try await repository.sendMotion(rideId: ride.view.rideId, motions: batch, sentAt: now())
            guard var current = state, current.view.rideId == ride.view.rideId else { return }
            pending.removeFirst(min(batch.count, pending.count))
            current.view = view
            current.online = true
            current.updatedAt = now()
            current.unsentMotions = pending.count
            set(current)
        } catch let error as APIError {
            // 서버가 거절한 움직임은 다시 보내도 같으니 버린다(계속 막히지 않게)
            if error == .badRequest { pending.removeFirst(min(batch.count, pending.count)) }
            if error == .notFound {
                set(nil)
                pending = []
                lostNotice = true
            } else if var current = state {
                current.online = false
                current.unsentMotions = pending.count
                set(current)
            }
        } catch {
            if var current = state { current.online = false; set(current) }
        }
    }

    private func set(_ new: ActiveRide?) {
        let old = state
        state = new
        if old != new { onChange?(old, new) }
    }
}
