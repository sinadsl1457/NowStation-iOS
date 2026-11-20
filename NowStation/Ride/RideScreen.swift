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
            if RideTexts.showsAlightScreen(ride) {
                AlightContent(ride: ride, onEnd: { confirming = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                RidingContent(ride: ride, probe: probe, loadStrip: loadStrip, onPick: onPick, onEnd: { confirming = true })
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.45), value: RideTexts.showsAlightScreen(ride))
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
        let warn = v.notice == .transfer || v.prepareToAlight
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
 * 세로 "다가오는 열차"(사용자가 시안 B로 정함, Android StripCard와 같은 배치): 타기 전에는 타는 역 위로 들어오는 역들을 세로로 놓고
 * 열차 점이 아래(타는 역)로 내려온다. 누르는 곳은 점이 아니라 열차마다 한 줄(높이 60 이상, 도착 순서로 고정).
 * 공공 데이터는 역에 들어설 때만 바뀌어, 그 사이는 역간 평균 시간으로 점을 이어 움직인다(다음 역 직전에서 멈춰 데이터를 기다림).
 * 서버에는 5초마다 묻는다(서버가 받아 둔 값이라 서울시 API 한도와 무관).
 */
private struct StripCard: View {
    let ride: ActiveRide
    let load: () async throws -> TrainStrip?
    let onPick: (StripTrain, String) async throws -> Void

    @State private var strip: TrainStrip?
    @State private var receivedAt = Date()
    @State private var picking: String?
    @State private var failed = false

    var body: some View {
        Group {
            if let strip {
                TimelineView(.periodic(from: .now, by: 0.1)) { ctx in
                    board(strip, now: ctx.date)
                }
            } else {
                Text(failed ? "열차 정보를 받지 못했어요. 잠시 후 다시 받아 와요." : "열차를 받아 오는 중…")
                    .font(.system(size: 14)).foregroundStyle(Color.muted).frame(maxWidth: .infinity, minHeight: 80)
                    .background(.white, in: RoundedRectangle(cornerRadius: 22))
            }
        }
        .task {
            while !Task.isCancelled {
                do { strip = try await load(); receivedAt = Date(); failed = false } catch is CancellationError { return } catch { failed = true }
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    @ViewBuilder private func board(_ strip: TrainStrip, now: Date) -> some View {
        let c = Color.line(strip.leg.line)
        let selected = strip.trains.first(where: \.selected)
        let selIdx = selected.flatMap { strip.stations.firstIndex(of: $0.station) } ?? -1
        let riding = selIdx > strip.boardIndex || (selIdx == strip.boardIndex && selected?.status == "DEPARTED")
        let from = riding ? strip.boardIndex : 0
        let to = riding ? strip.stations.count - 1 : min(strip.boardIndex + 1, strip.stations.count - 1)
        let window = Array(strip.stations[from...to])
        let gap: CGFloat = riding ? 40 : 60
        let incoming = strip.trains
            .filter { (strip.stations.firstIndex(of: $0.station) ?? .max) <= strip.boardIndex && $0.etaMinutes != nil }
            .sorted { (strip.stations.firstIndex(of: $0.station) ?? 0) > (strip.stations.firstIndex(of: $1.station) ?? 0) }
        let shown = riding ? [selected].compactMap { $0 } : incoming

        VStack(alignment: .leading, spacing: 12) {
            if !riding, let first = incoming.first { nextCard(first, line: strip.leg.line) }
            HStack(alignment: .top, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(c).frame(width: 4, height: CGFloat(window.count - 1) * gap).offset(x: 66, y: 14)
                    ForEach(Array(window.enumerated()), id: \.offset) { k, name in
                        let isBoard = from + k == strip.boardIndex
                        let passed = riding && selIdx >= 0 && from + k < selIdx
                        HStack(spacing: isBoard ? 3 : 6) {
                            Text(name).font(.system(size: 13, weight: isBoard ? .black : .regular)).lineLimit(1).minimumScaleFactor(0.7)
                                .foregroundStyle(isBoard ? Color.brand : passed ? Color(hex: 0xA8B0BF) : Color.ink)
                                .frame(width: 56, alignment: .trailing)
                            Circle().fill(.white).frame(width: isBoard ? 18 : 12, height: isBoard ? 18 : 12)
                                .overlay(Circle().stroke(isBoard ? Color.brand : c, lineWidth: 3))
                        }
                        .frame(height: 20).offset(y: CGFloat(k) * gap + 4)
                    }
                    ForEach(shown) { t in
                        if let p = position(t, strip: strip, from: from, now: now), p > -0.5, p < CGFloat(window.count) - 0.5 {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 6).fill(t.selected ? c : Color(hex: 0xC9D1E0)).frame(width: 20, height: 20)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(.white, lineWidth: 2))
                                Text(t.trainNo).font(.system(size: 12, weight: .semibold).monospacedDigit()).foregroundStyle(Color(hex: 0x2A3348))
                            }
                            .offset(x: 58, y: p * gap + 2)
                        }
                    }
                }
                .frame(width: 124, height: CGFloat(window.count) * gap + 8, alignment: .topLeading)

                VStack(alignment: .leading, spacing: 8) {
                    if riding {
                        Text("내 열차가 아래로 내려가요").font(.system(size: 13, weight: .bold))
                        Text("\(strip.leg.to)까지 따라가요").font(.system(size: 13)).foregroundStyle(Color.muted)
                    } else {
                        Text("가까운 순 · 줄을 눌러 고르기").font(.system(size: 11)).foregroundStyle(Color.muted)
                        ForEach(incoming) { t in row(t, line: strip.leg.line) }
                        if incoming.isEmpty { Text("지금 들어오는 열차가 없어요").font(.system(size: 13)).foregroundStyle(Color.muted) }
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
        }
    }

    /** 받은 위치 사이 움직임: 정차 시간이 지나면 다음 역 쪽으로, 다음 역 직전(0.92)에서 데이터를 기다린다. */
    private func position(_ t: StripTrain, strip: TrainStrip, from: Int, now: Date) -> CGFloat? {
        guard let i = strip.stations.firstIndex(of: t.station) else { return nil }
        let dwell = Double(strip.dwellSeconds ?? 30)
        let travel = max(Double(strip.secondsPerStop ?? 130) - dwell, 30)
        let elapsed = Double(t.atStationSeconds ?? 0) + now.timeIntervalSince(receivedAt)
        let p: Double
        switch t.status {
        case "ENTERING": p = -0.12
        case "DEPARTED": p = min(max(elapsed / travel, 0), 0.92)
        default: p = min(max((elapsed - dwell) / travel, 0), 0.92)
        }
        return CGFloat(Double(i - from) + p)
    }

    /** 열차 번호는 행선지보다 2 크게, 세미볼드(사용자 결정). */
    private func title(_ t: StripTrain, color: Color, no: CGFloat, terminal: CGFloat) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(t.trainNo).font(.system(size: no, weight: .semibold).monospacedDigit())
            Text(RideTexts.terminal(t)).font(.system(size: terminal, weight: .heavy))
        }
        .foregroundStyle(color)
    }

    private func pick(_ t: StripTrain, line: String) {
        guard picking == nil, !t.selected else { return }
        picking = t.trainNo
        Task {
            try? await onPick(t, line)
            if let s = try? await load() { strip = s; receivedAt = Date() }
            picking = nil
        }
    }

    private func row(_ t: StripTrain, line: String) -> some View {
        let c = Color.line(line)
        return Button { pick(t, line: line) } label: {
            VStack(alignment: .leading, spacing: 2) {
                title(t, color: t.selected ? .white : Color.ink, no: 17, terminal: 15)
                Text(picking == t.trainNo ? "고르는 중…" : "\(t.message ?? t.station) · \(RideTexts.eta(t))")
                    .font(.system(size: 13)).foregroundStyle(t.selected ? Color.white.opacity(0.85) : Color.muted)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            .background(t.selected ? c : .white, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.selected ? c : Color(hex: 0xE3E8F2), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("train-\(t.trainNo)")
    }

    /** 맨 위 "다음 열차": 이것 하나만 봐도 무엇을 탈지 안다. */
    private func nextCard(_ t: StripTrain, line: String) -> some View {
        let on = t.selected
        return Button { pick(t, line: line) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("다음 열차").font(.system(size: 12, weight: .bold)).opacity(0.85)
                    title(t, color: on ? .white : Color.ink, no: 24, terminal: 20)
                    Text("\(t.message ?? t.station) · \(RideTexts.eta(t))").font(.system(size: 15))
                }
                Spacer()
                Text(on ? "선택됨" : "이 열차 탈게요").font(.system(size: 14, weight: .bold))
                    .foregroundStyle(on ? Color.brand : .white)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(on ? Color.white : Color.brand, in: RoundedRectangle(cornerRadius: 12))
            }
            .foregroundStyle(on ? .white : Color.ink)
            .padding(.horizontal, 18).padding(.vertical, 16)
            .background(on ? Color.brand : .white, in: RoundedRectangle(cornerRadius: 20))
        }
        .buttonStyle(.plain)
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
