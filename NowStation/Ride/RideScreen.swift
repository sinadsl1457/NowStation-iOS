import SwiftUI

/** 탑승 중. 내릴 역 직전이면 화면 전체를 파랑으로 바꿔 주머니에서 꺼냈을 때 바로 알아보게 한다. */
struct RideScreen: View {
    let ride: ActiveRide
    var probe: SensorDriftProbe?
    /** 가로 노선도 받기·다른 열차 고르기(없으면 노선도를 그리지 않음: 화면 미리보기·테스트). */
    var loadStrip: (() async throws -> TrainStrip?)? = nil
    var onPick: ((StripTrain, String) async throws -> Void)? = nil
    let onEnd: () -> Void
    // 끝내기는 되돌릴 수 없어서(현재역 표시·내릴 역 알림이 멈춤) 한 번 더 묻는다
    @State private var confirming = false

    var body: some View {
        ZStack {
            if ride.view.prepareToAlight {
                AlightContent(ride: ride, onEnd: { confirming = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                RidingContent(ride: ride, probe: probe, loadStrip: loadStrip, onPick: onPick, onEnd: { confirming = true })
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.45), value: ride.view.prepareToAlight)
        .alert("탑승을 끝낼까요?", isPresented: $confirming) {
            Button("계속 타기", role: .cancel) {}
            Button("끝내기", role: .destructive, action: onEnd)
        } message: {
            Text("끝내면 현재역 표시와 내릴 역 알림이 멈춰요.")
        }
    }
}

private struct RidingContent: View {
    let ride: ActiveRide
    var probe: SensorDriftProbe?
    var loadStrip: (() async throws -> TrainStrip?)?
    var onPick: ((StripTrain, String) async throws -> Void)?
    let onEnd: () -> Void

    var body: some View {
        let v = ride.view
        ScrollView {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let line = v.line { LineChip(line: line) }
                Spacer()
                StatusPill(ride: ride)
            }

            BannerView(ride: ride)

            VStack(alignment: .leading, spacing: 4) {
                Text(v.status == .waiting ? "기다리는 역" : v.thisStation == nil ? "위치 확인 중" : "이번 정거장은")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
                Text(v.thisStation ?? ride.origin)
                    .font(.system(size: 60, weight: .black)).minimumScaleFactor(0.5).lineLimit(1)
                Text(RideTexts.remaining(ride) ?? RideTexts.detail(ride))
                    .font(.system(size: 17, weight: .semibold)).foregroundStyle(Color(hex: 0x2A3348))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))

            if !v.legs.isEmpty { LegChips(legs: v.legs, current: v.line) }
            if let loadStrip, let onPick { StripCard(ride: ride, load: loadStrip, onPick: onPick) } else { RouteCard(ride: ride) }

            Label("화면을 꺼도 잠금화면에서 계속 보여요", systemImage: "lock")
                .font(.footnote).foregroundStyle(Color.muted).padding(.horizontal, 6)
            if let probe {
                // 확인용(지울 것): 이전 방식이었다면 움직임 시각이 몇 초 과거로 찍혔을지
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    if let d = probe.drift() {
                        Text("확인용 · 센서 시각 어긋남(이전 방식) \(Int(d.rounded()))초")
                            .font(.caption2.monospacedDigit()).foregroundStyle(.orange).padding(.horizontal, 6)
                    }
                }
            }
            Button(action: onEnd) {
                Text("탑승 끝내기").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: 0x2A3348))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xD5DCE8), lineWidth: 1))
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Color.ground)
    }
}

/** 따라가는 열차와 환승 안내. */
private struct BannerView: View {
    let ride: ActiveRide

    var body: some View {
        let v = ride.view
        let warn = v.notice == .transfer
        HStack(spacing: 8) {
            Image(systemName: warn ? "arrow.triangle.2.circlepath" : "tram.fill")
            Text(RideTexts.banner(ride)).font(.system(size: 14, weight: .semibold)).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(warn ? Color(hex: 0xB45309) : Color.brand)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(warn ? Color(hex: 0xFFF4E5) : Color.brandTint))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("ride-banner")
    }
}

/** 경로 구간: "태평 ▶ 선릉" "선릉 ▶ 강남". 지금 구간을 칠한다. */
private struct LegChips: View {
    let legs: [RideLeg]
    let current: String?

    var body: some View {
        HStack(spacing: 8) {
            ForEach(legs, id: \.self) { leg in
                let on = leg.line == current
                HStack(spacing: 4) {
                    LineBadge(line: leg.line, size: 18)
                    Text("\(leg.from) ▶ \(leg.to)").font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal, 10).padding(.vertical, 6)
                .foregroundStyle(on ? Color.white : Color.ink)
                .background(Capsule().fill(on ? Color.line(leg.line) : Color.white))
                .overlay(Capsule().stroke(Color.line(leg.line), lineWidth: on ? 0 : 1.5))
            }
        }
    }
}

/**
 * 가로 노선도(이번정거장 4708과 같은 배치): 역이 한 줄로 늘어서고 그 위에 열차. 골라 둔 열차는 칠하고, 다른 열차를 누르면 그 열차로.
 * 공공 데이터가 늦어 15초마다 다시 받는다.
 */
private struct StripCard: View {
    let ride: ActiveRide
    let load: () async throws -> TrainStrip?
    let onPick: (StripTrain, String) async throws -> Void

    @State private var strip: TrainStrip?
    @State private var picking: String?
    @State private var failed = false

    private static let cell: CGFloat = 76

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let strip {
                HStack {
                    Text("\(strip.leg.from) → \(strip.leg.to) 방향 열차").font(.system(size: 14, weight: .bold))
                    Spacer()
                    Text(strip.trains.map(\.seenSecondsAgo).min().map { "\($0)초 전 기준" } ?? "")
                        .font(.caption).foregroundStyle(Color.muted)
                }
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .bottom, spacing: 0) {
                            ForEach(Array(strip.stations.enumerated()), id: \.offset) { i, name in
                                column(strip, index: i, name: name).id(i)
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                    .onAppear { proxy.scrollTo(focus(strip), anchor: .center) }
                }
            } else {
                Text(failed ? "열차 정보를 받지 못했어요. 잠시 후 다시 받아 와요." : "노선도를 받아 오는 중…")
                    .font(.system(size: 14)).foregroundStyle(Color.muted).frame(maxWidth: .infinity, minHeight: 80)
            }
        }
        .padding(16)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
        .task {
            while !Task.isCancelled {
                do { strip = try await load(); failed = false } catch is CancellationError { return } catch { failed = true }
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    /** 골라 둔 열차, 없으면 타는 역을 가운데로. */
    private func focus(_ strip: TrainStrip) -> Int {
        strip.trains.first(where: \.selected).flatMap { t in strip.stations.firstIndex(of: t.station) } ?? strip.boardIndex
    }

    @ViewBuilder private func column(_ strip: TrainStrip, index: Int, name: String) -> some View {
        let trains = strip.trains.filter { $0.station == name }
        VStack(spacing: 6) {
            VStack(spacing: 6) {
                ForEach(trains) { t in trainTag(t, line: strip.leg.line) }
            }
            .frame(minHeight: 62, alignment: .bottom)
            ZStack {
                Rectangle().fill(Color(hex: 0xC9D1E0)).frame(height: 3)
                Circle().fill(index == strip.boardIndex ? Color.line(strip.leg.line) : Color(hex: 0xC9D1E0))
                    .frame(width: index == strip.boardIndex ? 16 : 10, height: index == strip.boardIndex ? 16 : 10)
            }
            .frame(height: 18)
            Text(name).font(.system(size: 13, weight: index == strip.boardIndex ? .heavy : .regular))
                .foregroundStyle(index == strip.boardIndex ? Color.line(strip.leg.line) : Color.ink)
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: Self.cell)
    }

    private func trainTag(_ t: StripTrain, line: String) -> some View {
        Button {
            guard picking == nil, !t.selected else { return }
            picking = t.trainNo
            Task {
                try? await onPick(t, line)
                strip = try? await load()
                picking = nil
            }
        } label: {
            VStack(spacing: 2) {
                Text(RideTexts.terminal(t)).font(.system(size: 11, weight: .semibold))
                if picking == t.trainNo { ProgressView().controlSize(.mini) } else {
                    Text(t.trainNo).font(.system(size: 12, weight: .bold).monospacedDigit())
                }
                Image(systemName: "tram.fill").font(.system(size: 13))
            }
            .foregroundStyle(t.selected ? Color.white : Color.ink)
            .padding(.horizontal, 6).padding(.vertical, 5)
            .frame(width: Self.cell - 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(t.selected ? Color.line(line) : Color.white))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.selected ? Color.clear : Color(hex: 0xC9D1E0), lineWidth: 1.5))
        }
        .accessibilityIdentifier("train-\(t.trainNo)")
    }
}

private struct StatusPill: View {
    let ride: ActiveRide
    @State private var dim = false

    var body: some View {
        let live = ride.online && ride.view.status == .moving
        let color = ride.online ? Color.brand : Color.muted
        HStack(spacing: 8) {
            // 달리는 중이면 점이 숨 쉬듯 깜빡인다
            Circle().fill(color).frame(width: 8, height: 8)
                .opacity(live && dim ? 0.35 : 1)
                .animation(live ? .easeInOut(duration: 0.8).repeatForever() : .default, value: dim)
            Text(RideTexts.status(ride)).font(.system(size: 14, weight: .bold)).foregroundStyle(color)
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(ride.online ? Color.brandTint : Color(hex: 0xE9ECF2), in: Capsule())
        .onAppear { dim = true }
    }
}

/** 타는 역 → 내릴 역. 노선도(앞뒤 역)는 서버가 역 목록을 줄 때 붙인다. */
private struct RouteCard: View {
    let ride: ActiveRide

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Circle().fill(Color(hex: 0xC9D1E0)).frame(width: 12, height: 12)
                Text(ride.origin).font(.system(size: 16)).foregroundStyle(Color.muted)
                Spacer()
                Text("\(RideTexts.boardedTime(ride.startedAt)) 탑승")
                    .font(.caption.weight(.medium)).foregroundStyle(Color.muted)
            }
            Rectangle().fill(Color(hex: 0xB8C3D9)).frame(width: 2, height: 26).padding(.leading, 5)
            HStack(spacing: 16) {
                Circle().strokeBorder(Color.brand, lineWidth: 3).frame(width: 12, height: 12)
                Text(ride.destination ?? "내릴 역 없음")
                    .font(.system(size: 16, weight: ride.destination == nil ? .regular : .bold))
                    .foregroundStyle(ride.destination == nil ? Color.muted : Color.ink)
                Spacer()
                if ride.destination != nil {
                    Text("내릴 역").font(.caption.weight(.bold)).foregroundStyle(Color.brand)
                }
            }
        }
        .padding(.horizontal, 22).padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
    }
}

private struct AlightContent: View {
    let ride: ActiveRide
    let onEnd: () -> Void
    // 역 이름이 작게 시작해 커지며 나타난다
    @State private var grown = false

    var body: some View {
        let v = ride.view
        VStack(spacing: 0) {
            HStack {
                if let line = v.line { LineChip(line: line, onDark: true) }
                Spacer()
            }
            Spacer()
            Ripple()
            Text(RideTexts.isTransfer(ride) ? "갈아탈 준비하세요" : "내릴 준비하세요").font(.system(size: 30, weight: .black)).padding(.top, 18)
            Text("이번 역").font(.system(size: 16)).opacity(0.85).padding(.top, 10)
            Text(v.thisStation ?? "").font(.system(size: 76, weight: .black))
                .scaleEffect(grown ? 1 : 0.85)
            Text(RideTexts.isTransfer(ride) ? "여기서 갈아타세요" : "내리실 역이에요").font(.system(size: 16)).opacity(0.9)
            if let next = v.nextStation {
                Text("다음 역 \(next)").font(.system(size: 15)).opacity(0.7).padding(.top, 20)
            }
            Spacer()
            Button(action: onEnd) {
                Text("탑승 끝내기").font(.system(size: 17, weight: .bold)).foregroundStyle(Color.brand)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 24).padding(.vertical, 16)
        .background(Color.brand)
        .onAppear { withAnimation(.easeOut(duration: 0.5)) { grown = true } }
    }
}

/** 깃발에서 퍼지는 파동. Android와 같은 박자: 0, 0.6, 1.2초에 하나씩 1.3초 동안 퍼지고 3초마다 반복. */
private struct Ripple: View {
    private static let period = 3.0
    private static let spread = 1.3

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: Self.period)
            ZStack {
                ForEach([0.0, 0.6, 1.2], id: \.self) { start in
                    let p = (t - start) / Self.spread
                    if p >= 0 && p <= 1 {
                        Circle().stroke(Color.white.opacity(0.5 * (1 - p)), lineWidth: 2)
                            .frame(width: 76 + 144 * p, height: 76 + 144 * p)
                    }
                }
                Circle().fill(Color.white.opacity(0.18)).frame(width: 100, height: 100)
                Image(systemName: "flag.fill").font(.system(size: 30)).foregroundStyle(Color.brand)
                    .frame(width: 76, height: 76).background(.white, in: Circle())
            }
            .frame(width: 220, height: 220)
        }
    }
}
