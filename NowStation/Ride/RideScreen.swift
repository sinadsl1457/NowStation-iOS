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
            // 파란 전체 화면은 최종 내릴 역에서만. 환승역은 알림·진동과 안내 띠로(사용자 결정)
            if ride.view.prepareToAlight && !RideTexts.isTransfer(ride) {
                AlightContent(ride: ride, onEnd: { confirming = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                RidingContent(ride: ride, probe: probe, loadStrip: loadStrip, onPick: onPick, onEnd: { confirming = true })
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.45), value: ride.view.prepareToAlight && !RideTexts.isTransfer(ride))
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

            if v.legs.contains(where: { !$0.stations.isEmpty }) { RouteBar(legs: v.legs, here: v.thisStation, currentLine: v.line) }
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

/**
 * 전체 경로 막대: 출발부터 도착까지 실제로 지나는 역만 한 줄로, 구간마다 노선 색. 환승역에는 두 노선 배지.
 * 환승해도 막대는 그대로라 화면이 갑자기 바뀌지 않는다(사용자 피드백: 선릉에서 갑자기 2호선 노선도로 바뀌어 헷갈림). Android RouteBar와 같은 배치.
 */
private struct RouteBar: View {
    let legs: [RideLeg]
    let here: String?
    let currentLine: String?

    private struct Stop: Hashable { var name: String; var inLine: String?; var outLine: String? }

    private var stops: [Stop] {
        var out: [Stop] = []
        for (li, leg) in legs.enumerated() {
            for (si, name) in leg.stations.enumerated() {
                if li > 0 && si == 0, var last = out.popLast() {
                    last.outLine = leg.line
                    out.append(last)
                } else {
                    out.append(Stop(name: name, inLine: si == 0 ? nil : leg.line, outLine: si == leg.stations.count - 1 ? nil : leg.line))
                }
            }
        }
        return out
    }

    var body: some View {
        let stops = self.stops
        // 지금 위치: 지금 노선 구간 안의 이번 역(환승역 이름은 두 구간에 있어 노선으로 가린다)
        let hereIndex = stops.firstIndex { $0.name == here && ($0.inLine == currentLine || $0.outLine == currentLine) }
        VStack(alignment: .leading, spacing: 8) {
            Text("\(stops.first?.name ?? "") → \(stops.last?.name ?? "")").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted)
                .padding(.horizontal, 16)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 0) {
                        ForEach(Array(stops.enumerated()), id: \.offset) { i, stop in
                            let transfer = stop.inLine != nil && stop.outLine != nil && stop.inLine != stop.outLine
                            let isHere = i == hereIndex
                            VStack(spacing: 4) {
                                ZStack {
                                    HStack(spacing: 0) {
                                        Rectangle().fill(stop.inLine.map { Color.line($0) } ?? .clear).frame(height: 5)
                                        Rectangle().fill(stop.outLine.map { Color.line($0) } ?? .clear).frame(height: 5)
                                    }
                                    let c = Color.line(stop.outLine ?? stop.inLine)
                                    Circle().fill(isHere ? c : .white)
                                        .frame(width: isHere ? 20 : transfer ? 16 : 11, height: isHere ? 20 : transfer ? 16 : 11)
                                        .overlay(Circle().stroke(transfer ? Color.ink : c, lineWidth: 3))
                                }
                                .frame(height: 22)
                                Text(stop.name).font(.system(size: 12, weight: isHere || transfer ? .heavy : .regular))
                                    .foregroundStyle(isHere ? Color.line(currentLine) : Color.ink).lineLimit(1).minimumScaleFactor(0.7)
                                if transfer, let a = stop.inLine, let b = stop.outLine {
                                    HStack(spacing: 2) { LineBadge(line: a, size: 20); LineBadge(line: b, size: 20) }
                                }
                                if isHere { Text("지금").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.line(currentLine)) }
                            }
                            .frame(width: 64)
                            .id(i)
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .onAppear { if let h = hereIndex { proxy.scrollTo(max(h - 2, 0), anchor: .leading) } }
                .onChange(of: hereIndex) { _, h in if let h { withAnimation { proxy.scrollTo(max(h - 2, 0), anchor: .leading) } } }
            }
        }
        .padding(.vertical, 14)
        .background(.white, in: RoundedRectangle(cornerRadius: 24))
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
                if strip.boardIndex > 0 {
                    Text("회색 역: 열차가 \(strip.leg.from)(으)로 들어오는 쪽").font(.caption2).foregroundStyle(Color.muted)
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
            .frame(minHeight: 74, alignment: .bottom)
            ZStack {
                Rectangle().fill(index >= strip.boardIndex ? Color.line(strip.leg.line) : Color(hex: 0xC9D1E0)).frame(height: 3)
                Circle().fill(index == strip.boardIndex ? Color.line(strip.leg.line) : Color(hex: 0xC9D1E0))
                    .frame(width: index == strip.boardIndex ? 16 : 10, height: index == strip.boardIndex ? 16 : 10)
            }
            .frame(height: 18)
            Text(name).font(.system(size: 13, weight: index == strip.boardIndex ? .heavy : .regular))
                // 타는 역 앞쪽(들어오는 열차가 오는 쪽)은 내 경로가 아니라 흐리게
                .foregroundStyle(index == strip.boardIndex ? Color.line(strip.leg.line) : index < strip.boardIndex ? Color(hex: 0xA8B0BF) : Color.ink)
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
                if let state = RideTexts.trainState(t) { Text(state).font(.system(size: 10)).opacity(0.8) }
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
            let arrived = v.status == .arrived
            let target = v.target ?? v.thisStation
            Text(arrived ? "도착했어요" : RideTexts.isTransfer(ride) ? "갈아탈 준비하세요" : "내릴 준비하세요").font(.system(size: 30, weight: .black)).padding(.top, 18)
            // 한 정거장 전부터 켜진다: 아직 전 역이면 "다음 역"
            Text(arrived || v.thisStation == target ? "이번 역" : "다음 역").font(.system(size: 16)).opacity(0.85).padding(.top, 10)
            Text(target ?? "").font(.system(size: 76, weight: .black))
                .scaleEffect(grown ? 1 : 0.85)
            Text(RideTexts.isTransfer(ride) ? "여기서 갈아타세요" : "내리실 역이에요").font(.system(size: 16)).opacity(0.9)
            if !ride.online {
                // 연결이 끊기면 보이는 역이 오래된 것일 수 있다(갈아탈·내릴 준비 화면에서도)
                Label("연결 끊김(다시 시도 중)", systemImage: "wifi.slash").font(.system(size: 14, weight: .semibold)).padding(.top, 10)
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
