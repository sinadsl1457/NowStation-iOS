import SwiftUI

/**
 * 탑승 시작 직후 "지금 탄 열차"를 고른다. 폰 움직임으로 맞히기는 걷는 중·늦게 켬에서 실패해서(2026-11-19 실기기)
 * 사용자가 고르는 것이 먼저다. 공공 데이터가 늦어 목록은 15초마다 다시 받는다. Android TrainPickScreen과 같은 흐름.
 */
struct TrainPickScreen: View {
    let ride: ActiveRide
    let load: () async throws -> [TrainChoice]
    let onPick: (TrainChoice) async throws -> Void
    let onUnsure: () -> Void
    let onNotYet: () -> Void

    @State private var trains: [TrainChoice] = []
    @State private var loaded = false
    @State private var failed = false
    @State private var picking: String?
    @State private var pickFailed = false

    private static let refreshSeconds: UInt64 = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("지금 타고 있는 열차를 골라 주세요")
                    .font(.system(size: 24, weight: .black))
                Text("\(ride.origin) → \(ride.destination ?? "")")
                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.muted)
            }

            content

            Spacer(minLength: 0)
            VStack(spacing: 10) {
                Button(action: onUnsure) {
                    Text("목록에 없어요 / 모르겠어요")
                        .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.brand)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 14))
                }
                Button(action: onNotYet) {
                    Text("아직 안 탔어요")
                        .font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            }
            .disabled(picking != nil)
        }
        .foregroundStyle(Color.ink)
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.ground)
        .alert("열차를 고르지 못했어요", isPresented: $pickFailed) {
            Button("확인", role: .cancel) {}
        } message: {
            Text("방금 목록에서 사라진 열차일 수 있어요. 다시 골라 주세요.")
        }
        .task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: Self.refreshSeconds * 1_000_000_000)
            }
        }
    }

    @ViewBuilder private var content: some View {
        if !loaded {
            HStack(spacing: 10) { ProgressView(); Text("열차를 찾는 중…").foregroundStyle(Color.muted) }
                .frame(maxWidth: .infinity, minHeight: 120)
        } else if trains.isEmpty {
            Text(failed ? "열차 정보를 받지 못했어요. 잠시 후 다시 받아 와요." : "지금 이 구간에 보이는 열차가 없어요.")
                .font(.system(size: 15)).foregroundStyle(Color.muted)
                .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("\(RideTexts.seenAgo(trains.map(\.seenSecondsAgo).min() ?? 0)) · 실제보다 한두 정거장 늦게 보일 수 있어요")
                    .font(.caption).foregroundStyle(Color.muted)
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(trains) { train in
                            TrainRow(train: train, busy: picking == train.id) { pick(train) }
                                .disabled(picking != nil)
                        }
                    }
                }
            }
        }
    }

    private func refresh() async {
        do {
            trains = try await load()
            failed = false
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
        loaded = true
    }

    private func pick(_ train: TrainChoice) {
        picking = train.id
        Task {
            do { try await onPick(train) } catch { pickFailed = true; await refresh() }
            picking = nil
        }
    }
}

private struct TrainRow: View {
    let train: TrainChoice
    let busy: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                LineBadge(line: train.line, size: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(RideTexts.trainPlace(train)).font(.system(size: 18, weight: .bold))
                    if let terminal = RideTexts.trainTerminal(train) {
                        Text(terminal).font(.system(size: 14)).foregroundStyle(Color.muted)
                    }
                }
                Spacer()
                if busy { ProgressView() } else { Image(systemName: "chevron.right").foregroundStyle(Color.muted) }
            }
            .foregroundStyle(Color.ink)
            .padding(16)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
        .accessibilityIdentifier("train-\(train.trainNo)")
    }
}
