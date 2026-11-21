import SwiftUI

/** 홈. 역 검색은 칸을 눌렀을 때만 덮어서 연다(첫 화면에 긴 목록을 깔지 않음). Android 홈과 같은 배치. */
struct HomeView: View {
    @Bindable var vm: HomeViewModel
    var onShowGuide: () -> Void = {}
    @State private var showSettings = false
    @Environment(\.launchIntro) private var intro

    var body: some View {
        // 첫 실행 애니메이션 동안만 매 화면 갱신마다 다시 그린다
        TimelineView(.animation(paused: intro == nil)) { timeline in
            let f = intro.map { LaunchIntro.Frame(t: $0.time(timeline.date)) }
            ScrollView {
                VStack(spacing: 0) {
                    Header(frame: f, onShowSettings: { showSettings = true }) { intro?.track = $0 }
                    VStack(alignment: .leading, spacing: 24) {
                        HomeRouteCard(vm: vm)
                        Group {
                            if vm.recent.isEmpty { HowItWorks() } else { RecentRoutes(vm: vm) }
                            if !vm.lines.isEmpty { SupportedLines(lines: vm.lines) }
                            // 공공데이터 이용 조건: 출처 표시
                            Text("열차 위치: 서울특별시 열린데이터광장 실시간 지하철 정보")
                                .font(.caption2).foregroundStyle(Color.muted)
                                .frame(maxWidth: .infinity)
                                .padding(.bottom, 24)
                        }
                        .opacity(f?.below ?? 1)
                    }
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 20)
                    .offset(y: -60)
                    .padding(.bottom, -60)
                }
            }
            .scrollDisabled(f != nil)
        }
        .background(Color.ground)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $vm.searching) { StationSearchView(vm: vm) }
        .sheet(isPresented: $showSettings) { SettingsView(onShowGuide: onShowGuide) }
        .alert(vm.message ?? "", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("확인", role: .cancel) {}
        }
        .task { await vm.load() }
    }
}

private struct Header: View {
    var frame: LaunchIntro.Frame?
    var onShowSettings: () -> Void = {}
    var onTrack: (CGRect) -> Void = { _ in }
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.brand
            Group {
                Circle().stroke(Color.white.opacity(0.12), lineWidth: 2)
                    .frame(width: 240, height: 240).offset(x: 190, y: 60)
                Circle().stroke(Color.white.opacity(0.18), lineWidth: 2)
                    .frame(width: 150, height: 150).offset(x: 205, y: 125)
            }
            .opacity(frame?.title ?? 1)
            // 설정(사용법 다시 보기·알림·문의·개인정보처리방침)
            Button(action: onShowSettings) {
                Image(systemName: "gearshape").font(.system(size: 20, weight: .medium)).foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("설정")
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.top, 68).padding(.trailing, 14)
            .opacity(frame?.title ?? 1)
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("지금역").font(.system(size: 30, weight: .black)).foregroundStyle(.white)
                        Text("v\(version)").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                    }
                    Text("열차에 타서 지금 탄 열차를 고르면\n잠금화면에 현재역을 보여 줘요")
                        .font(.system(size: 16)).foregroundStyle(.white.opacity(0.88))
                        .padding(.top, 6)
                }
                .opacity(frame?.title ?? 1)
                TrackDecoration().frame(width: 250, height: 24)
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onTrack($0) }
                    .opacity(frame?.handoff ?? 1)
                    .padding(.top, 22)
            }
            .padding(.horizontal, 24)
            .padding(.top, 76)
            // 첫 실행 애니메이션: 처음엔 화면 전체(시작 화면과 같은 파란 화면)였다가 원래 높이로 줄며 카드가 따라 올라온다
            .padding(.bottom, 92 + (frame.map { LaunchIntro.screenHeight * (1 - $0.shrink) } ?? 0))
        }
        .clipped()
    }
}

/** 노선 위 "지금 여기" 그림. */
private struct TrackDecoration: View {
    var body: some View {
        Canvas { ctx, size in
            let y = size.height / 2
            let xs = [0.0, 0.33, 0.66, 1.0].map { $0 * (size.width - 12) + 6 }
            func line(_ a: Double, _ b: Double, _ color: Color, dash: [CGFloat] = []) {
                var p = Path(); p.move(to: CGPoint(x: a, y: y)); p.addLine(to: CGPoint(x: b, y: y))
                ctx.stroke(p, with: .color(color), style: StrokeStyle(lineWidth: 3, dash: dash))
            }
            func dot(_ x: Double, _ r: Double, _ color: Color, stroke: Bool = false) {
                let rect = CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)
                if stroke { ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2) } else { ctx.fill(Path(ellipseIn: rect), with: .color(color)) }
            }
            line(xs[0], xs[1], .white.opacity(0.45))
            line(xs[1], xs[2], .white)
            line(xs[2], xs[3], .white.opacity(0.55), dash: [4, 4])
            dot(xs[0], 5, .white.opacity(0.45))
            dot(xs[1], 5, .white.opacity(0.45))
            dot(xs[2], 16, .white.opacity(0.25))
            dot(xs[2], 10, .white)
            dot(xs[3], 5, .white.opacity(0.7), stroke: true)
        }
    }
}

struct HomeRouteCard: View {
    @Bindable var vm: HomeViewModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                VStack(spacing: 0) {
                    StationField(label: "타는 역", station: vm.origin, filled: true) { vm.edit(.origin) }
                    HStack(spacing: 14) {
                        Rectangle().fill(Color(hex: 0xB8C3D9)).frame(width: 2, height: 14).padding(.horizontal, 5)
                        Rectangle().fill(Color(hex: 0xEEF1F6)).frame(height: 1)
                    }
                    StationField(label: "내릴 역", station: vm.destination, filled: false) { vm.edit(.destination) }
                }
                // 타는 역 ↔ 내릴 역(퇴근길)
                Button { withAnimation(.easeOut(duration: 0.2)) { vm.swap() } } label: {
                    Image(systemName: "arrow.up.arrow.down").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(vm.canSwap ? Color.brand : Color.muted.opacity(0.4))
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.hairline, lineWidth: 1))
                }
                .disabled(!vm.canSwap)
                .accessibilityLabel("타는 역과 내릴 역 바꾸기")
            }
            if vm.sameStation {
                Text("타는 역과 내릴 역이 같아요").font(.footnote).foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 26).padding(.top, 4)
            }
            Button {
                Task { await vm.start() }
            } label: {
                Label(vm.isStarting ? "시작하는 중…" : "탑승 시작", systemImage: "tram.fill")
                    .font(.system(size: 17, weight: .bold))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .foregroundStyle(vm.canStart ? Color.white : Color.muted.opacity(0.6))
                    .background(vm.canStart ? Color.brand : Color(hex: 0xE6E9EF), in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!vm.canStart)
            .padding(.top, 12)
        }
        .padding(.horizontal, 18).padding(.top, 8).padding(.bottom, 18)
        // 그림자는 카드 바탕에만(안의 칩·버튼에 번지지 않게)
        .background(RoundedRectangle(cornerRadius: 22).fill(.white).shadow(color: Color.brand.opacity(0.12), radius: 16, y: 6))
    }
}

private struct StationField: View {
    let label: String
    let station: Station?
    let filled: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Group {
                if filled { Circle().fill(Color.brand) } else { Circle().strokeBorder(Color.brand, lineWidth: 3) }
            }
            .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption.weight(.medium)).foregroundStyle(Color.muted).lineLimit(1).fixedSize()
                Text(station?.name ?? "고르기")
                    .font(.system(size: 19, weight: station == nil ? .regular : .bold))
                    .foregroundStyle(station == nil ? Color.muted : Color.ink)
                    .lineLimit(1)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            if let lines = station?.lines { LineBadges(lines: lines) }
        }
        .frame(minHeight: 60)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}

private struct SectionTitle: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 15, weight: .bold)).foregroundStyle(Color(hex: 0x2A3348)).padding(.horizontal, 4)
    }
}

private struct RecentRoutes: View {
    @Bindable var vm: HomeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "최근 경로")
            ForEach(Array(vm.recent.enumerated()), id: \.offset) { _, route in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { vm.useRecent(route) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "clock").foregroundStyle(Color.brand)
                            .frame(width: 38, height: 38)
                            .background(Color.brandTint, in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text([route.origin.name, route.destination?.name].compactMap { $0 }.joined(separator: " → "))
                                .font(.system(size: 16, weight: .bold)).foregroundStyle(Color.ink)
                            HStack(spacing: 6) {
                                ForEach(Array(Set(route.origin.lines + (route.destination?.lines ?? []))).sorted(), id: \.self) { line in
                                    Circle().fill(Color.line(line)).frame(width: 8, height: 8)
                                    Text(line).font(.caption.weight(.medium)).foregroundStyle(Color.muted)
                                }
                            }
                        }
                        Spacer()
                        // 누르면 위 칸에 채운다(바로 시작하지 않음). ↖ = 검색 추천어처럼 "입력칸에 넣기"(›는 다음 화면으로 보여서 뺐다)
                        Image(systemName: "arrow.up.left").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.muted)
                            .accessibilityLabel("칸에 채우기")
                    }
                    .padding(.horizontal, 16).padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                }
                .disabled(vm.isStarting)
            }
        }
    }
}

/** 최근 경로가 없을 때(처음 쓰는 사람). */
private struct HowItWorks: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "이렇게 써요")
            VStack(alignment: .leading, spacing: 14) {
                step(1, "열차에 탄 뒤 타는 역·내릴 역을 고르고 탑승 시작")
                step(2, "목록에서 지금 탄 열차를 골라요")
                step(3, "잠금화면에 현재역, 내리기 전엔 진동")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func step(_ n: Int, _ text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(n)").font(.system(size: 14, weight: .bold)).foregroundStyle(Color.brand)
                .frame(width: 28, height: 28).background(Color.brandTint, in: Circle())
            Text(text).font(.system(size: 15))
        }
    }
}

private struct SupportedLines: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle(text: "지원하는 노선")
            HStack(spacing: 8) {
                ForEach(lines, id: \.self) { line in
                    HStack(spacing: 8) {
                        LineBadge(line: line, size: 22).accessibilityHidden(true)
                        Text(line).font(.system(size: 15, weight: .bold)).lineLimit(1)
                    }
                    .fixedSize()
                    .padding(.leading, 6).padding(.trailing, 14).padding(.vertical, 6)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
                }
            }
        }
    }
}

/**
 * 처음 켤 때: 시작 화면의 아이콘(가운데)이 홈 머리의 노선 그림으로 바뀌며 홈이 자리 잡는다(약 1.25초, Android와 같은 시간표).
 * 홈(머리 높이·글자 투명도)과 위 덮개([LaunchOverlay])가 같은 시간을 보고 그린다.
 */
@Observable @MainActor
final class LaunchIntro {
    static let total = 1.25
    static var screenHeight: CGFloat { UIScreen.main.bounds.height }
    /** 시작 화면 그림(LaunchLogo)과 같은 크기: 108 단위 아이콘 그림의 1단위 = 2.4pt */
    static let unit: CGFloat = 2.4

    var start: Date?
    /** 홈 노선 그림의 자리(화면 기준). */
    var track: CGRect?
    var finished = false

    func time(_ now: Date) -> Double { start.map { min(Self.total, now.timeIntervalSince($0)) } ?? 0 }

    struct Frame {
        let ripple, morph, handoff, title, shrink, below: Double
        init(t: Double) {
            func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
            func outCubic(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
            func inOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }
            ripple = clamp(t / 0.45)
            morph = inOut(clamp((t - 0.3) / 0.6))
            handoff = clamp((t - 0.8) / 0.2)
            title = outCubic(clamp((t - 0.55) / 0.4))
            shrink = outCubic(clamp((t - 0.6) / 0.5))
            below = clamp((t - 1.0) / 0.25)
        }
    }
}

extension EnvironmentValues {
    @Entry var launchIntro: LaunchIntro? = nil
}

/** 홈 위에 아이콘이 바뀌어 가는 모습을 그린다. 누르면 바로 끝낸다. */
struct LaunchOverlay: View {
    let intro: LaunchIntro

    var body: some View {
        TimelineView(.animation) { timeline in
            let f = LaunchIntro.Frame(t: intro.time(timeline.date))
            Canvas { ctx, size in draw(ctx, size, f) }
        }
        .ignoresSafeArea()
        .contentShape(Rectangle())
        .onTapGesture { intro.finished = true }
        .task {
            intro.start = .now
            try? await Task.sleep(for: .seconds(LaunchIntro.total))
            intro.finished = true
        }
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ f: LaunchIntro.Frame) {
        func lerp(_ a: CGFloat, _ b: CGFloat, _ k: Double) -> CGFloat { a + (b - a) * k }
        func circle(_ c: CGPoint, _ r: CGFloat) -> Path { Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)) }
        let u = LaunchIntro.unit
        let from = CGPoint(x: size.width / 2, y: size.height / 2)
        let track = intro.track
        let m = track == nil ? 0 : f.morph
        let left0 = track?.minX ?? 0
        let to = track.map { CGPoint(x: $0.minX + 163, y: $0.minY + 12) } ?? from
        let c = CGPoint(x: lerp(from.x, to.x, m), y: lerp(from.y, to.y, m))
        let alpha = 1 - f.handoff

        if f.ripple > 0 && f.ripple < 1 {
            let r = 14 * u + 55 * (1 - pow(1 - f.ripple, 3))
            ctx.stroke(circle(from, r), with: .color(.white.opacity(0.55 * (1 - f.ripple))), lineWidth: 1.5)
        }
        guard alpha > 0 else { return }
        let thick = lerp(5 * u, 3, m)
        let lineL = lerp(from.x - 25.5 * u, left0 + 6, m), lineR = lerp(from.x + 25.5 * u, left0 + 244, m)
        ctx.fill(Path(roundedRect: CGRect(x: lineL, y: c.y - thick / 2, width: lineR - lineL, height: thick), cornerRadius: thick / 2), with: .color(.white.opacity(alpha)))
        let dotR = lerp(4.5 * u, 5, m)
        ctx.fill(circle(CGPoint(x: lerp(from.x - 21 * u, left0 + 84.5, m), y: c.y), dotR), with: .color(.white.opacity(alpha * lerp(1, 0.45, m))))
        ctx.fill(circle(CGPoint(x: lerp(from.x + 21 * u, left0 + 244, m), y: c.y), dotR), with: .color(.white.opacity(alpha)))
        // 지금 역 링: 안쪽은 바탕색으로 채워 노선을 가린다(아이콘과 같게) → 끝에는 홈 그림의 옅은 테두리
        let outer = lerp(14 * u, 16, m), ring = lerp(5 * u, 6, m)
        ctx.fill(circle(c, outer - ring), with: .color(Color.brand.opacity(alpha)))
        ctx.stroke(circle(c, outer - ring / 2), with: .color(.white.opacity(alpha * lerp(1, 0.25, m))), lineWidth: ring)
        ctx.fill(circle(c, lerp(4.5 * u, 10, m)), with: .color(.white.opacity(alpha)))
    }
}
