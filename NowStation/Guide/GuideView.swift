import SwiftUI

/** 처음 실행 가이드를 끝까지(또는 건너뛰기로) 봤는지. 한 번 보면 다시 띄우지 않는다. */
enum GuideStore {
    private static let key = "guide_seen_v1"
    static var seen: Bool { UserDefaults.standard.bool(forKey: key) }
    static func markSeen() { UserDefaults.standard.set(true, forKey: key) }
}

private struct GuidePage: Identifiable {
    let id: Int
    let title: String
    let body: String
}

private let pages = [
    GuidePage(id: 0, title: "타는 역·내릴 역만 고르세요", body: "갈아타는 길은 앱이 정해요. 태평에서 강남이면 선릉에서 2호선으로 갈아타요."),
    GuidePage(id: 1, title: "탈 열차를 눌러요", body: "승강장 전광판처럼 내 역으로 들어오는 열차가 보여요. 다음 열차는 미리 골라 두고, 다른 열차를 탔다면 눌러서 바꿔요."),
    GuidePage(id: 2, title: "탔으면 폰은 넣어 두세요", body: "잠금화면과 다이나믹 아일랜드에 이번 역과 남은 정거장이 계속 바뀌어요. 다른 앱을 써도 괜찮아요."),
    GuidePage(id: 3, title: "한 정거장 전에 깨워 드려요", body: "갈아탈 역과 내릴 역 한 정거장 전에 진동과 알림이 와요. 무음 모드에서도요."),
]

private let suinBundang = Color(hex: 0xF5A200)
private let line2 = Color(hex: 0x00A84D)
private let bodyText = Color(hex: 0x3A4458)

/**
 * 처음 실행 가이드 4장(Android와 같은 글·그림). 옆으로 넘기면 위 그림이 글자보다 느리게 따라온다.
 * 마지막 장 버튼([onDone])에서 알림·위치 권한을 묻는다(앱을 켜자마자 묻지 않게).
 */
struct GuideView: View {
    let onDone: () -> Void
    @State private var page: Int? = 0
    private var current: Int { page ?? 0 }
    private var last: Bool { current == pages.count - 1 }

    var body: some View {
        GeometryReader { geo in
            let artHeight = geo.size.height * 0.56
            ZStack(alignment: .top) {
                Color.ground
                ZStack {
                    Color.brand
                    Circle().stroke(.white.opacity(0.12), lineWidth: 2).frame(width: 260, height: 260).offset(x: 130, y: -40)
                    Circle().stroke(.white.opacity(0.10), lineWidth: 2).frame(width: 200, height: 200).offset(x: -150, y: 150)
                }
                .frame(height: artHeight).clipped()

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(pages) { p in
                            GeometryReader { pg in
                                // 이 장이 가운데에서 얼마나 벗어났나(pt). 그림만 덜 움직이게 되돌린다
                                let shift = pg.frame(in: .named("guide")).minX
                                VStack(alignment: .leading, spacing: 0) {
                                    TimelineView(.animation) { tl in
                                        art(p.id, tl.date.timeIntervalSinceReferenceDate)
                                    }
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .offset(x: -shift * 0.35)
                                    .frame(height: artHeight - geo.safeAreaInsets.top - 36)
                                    .padding(.top, geo.safeAreaInsets.top + 36) // 건너뛰기 버튼 아래부터
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text(p.title).font(.system(size: 26, weight: .black)).foregroundStyle(Color.ink)
                                        Text(p.body).font(.system(size: 16)).lineSpacing(5).foregroundStyle(bodyText)
                                    }
                                    .padding(.horizontal, 28).padding(.top, 28)
                                    Spacer()
                                }
                            }
                            .frame(width: geo.size.width)
                            // 그림이 글자보다 느리게 움직여 옆 장으로 비어져 나온다 → 장마다 잘라 낸다
                            .clipped()
                            .id(p.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $page)
                .coordinateSpace(name: "guide")

                VStack(spacing: 14) {
                    Spacer()
                    HStack(spacing: 6) {
                        ForEach(pages) { p in
                            Capsule().fill(p.id == current ? Color.brand : Color(hex: 0xC9D1E0))
                                .frame(width: p.id == current ? 26 : 8, height: 8)
                        }
                        Spacer()
                    }
                    .animation(.easeOut(duration: 0.25), value: current)
                    Button {
                        if last { onDone() } else { withAnimation { page = current + 1 } }
                    } label: {
                        Text(last ? "알림 허용하고 시작하기" : "다음")
                            .font(.system(size: 17, weight: .bold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(Color.brand, in: RoundedRectangle(cornerRadius: 16))
                    }
                    Text(last ? "알림을 허용해야 잠금화면 표시와 진동 알림을 받아요" : " ")
                        .font(.caption).foregroundStyle(Color.muted)
                }
                .padding(.horizontal, 28).padding(.bottom, 12)

                if !last {
                    HStack {
                        Spacer()
                        Button("건너뛰기", action: onDone)
                            .font(.system(size: 15, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                            .frame(minWidth: 44, minHeight: 44).padding(.horizontal, 8)
                    }
                    .padding(.top, geo.safeAreaInsets.top)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    @ViewBuilder
    private func art(_ id: Int, _ time: Double) -> some View {
        switch id {
        case 0: RouteArt(t: time.truncatingRemainder(dividingBy: 3.2))
        case 1: BoardArt(t: time.truncatingRemainder(dividingBy: 3.6))
        case 2: LockArt(t: time.truncatingRemainder(dividingBy: 6))
        default: AlertArt(t: time.truncatingRemainder(dividingBy: 3))
        }
    }
}

private func clamp(_ x: Double) -> Double { min(1, max(0, x)) }
private func ease(_ x: Double) -> Double { 1 - pow(1 - x, 3) }

private extension View {
    func guideCard(_ radius: CGFloat = 22) -> some View {
        background(RoundedRectangle(cornerRadius: radius).fill(.white).shadow(color: Color(hex: 0x0A1E5A).opacity(0.25), radius: 16, y: 8))
    }
}

/** 1장: 역 두 칸이 채워지고, 앱이 정한 길(수인분당 → 선릉 → 2호선)이 그려진다. */
private struct RouteArt: View {
    let t: Double

    var body: some View {
        let yellow = ease(clamp((t - 0.6) / 0.9)), green = ease(clamp((t - 1.4) / 0.6))
        VStack(spacing: 20) {
            VStack(spacing: 0) {
                field("타는 역", "태평", filled: true, alpha: clamp(t / 0.3))
                Rectangle().fill(Color(hex: 0xEEF1F6)).frame(height: 1).padding(.leading, 24)
                field("내릴 역", "강남", filled: false, alpha: clamp((t - 0.3) / 0.3))
            }
            .padding(.horizontal, 18).padding(.vertical, 8)
            .guideCard()
            ZStack(alignment: .topLeading) {
                Text("앱이 정한 길").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.muted).padding(.leading, 18).padding(.top, 14)
                Text("2호선 갈아타기").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x00813B))
                    .padding(.horizontal, 8).padding(.vertical, 3).background(Color(hex: 0xE6F6EC), in: Capsule())
                    .offset(x: 118, y: 34).opacity(clamp((t - 1.3) / 0.3))
                Canvas { ctx, _ in
                    let y = 69.0, a = 31.0, m = 164.0, b = 297.0
                    func seg(_ from: Double, _ to: Double, _ c: Color) {
                        var p = Path(); p.move(to: CGPoint(x: from, y: y)); p.addLine(to: CGPoint(x: to, y: y))
                        ctx.stroke(p, with: .color(c), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    }
                    seg(a, b, Color(hex: 0xEEF1F6))
                    if yellow > 0 { seg(a, a + (m - a) * yellow, suinBundang) }
                    if green > 0 { seg(m, m + (b - m) * green, line2) }
                    func stop(_ x: Double, _ ring: Color) {
                        let r = CGRect(x: x - 7, y: y - 7, width: 14, height: 14)
                        ctx.fill(Path(ellipseIn: r.insetBy(dx: -2, dy: -2)), with: .color(.white))
                        ctx.stroke(Path(ellipseIn: r), with: .color(ring), lineWidth: 4)
                    }
                    stop(a, .brand)
                    stop(m, yellow >= 1 ? line2 : Color(hex: 0xC9D1E0))
                    stop(b, green >= 1 ? line2 : Color(hex: 0xC9D1E0))
                }
                HStack {
                    ForEach(["태평", "선릉", "강남"], id: \.self) { name in
                        Text(name).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.ink).frame(width: 40)
                        if name != "강남" { Spacer() }
                    }
                }
                .padding(.horizontal, 11).offset(y: 88)
            }
            .frame(height: 130)
            .guideCard()
        }
        .frame(width: 326)
    }

    private func field(_ label: String, _ value: String, filled: Bool, alpha: Double) -> some View {
        HStack(spacing: 12) {
            Circle().fill(filled ? Color.brand : .clear).overlay(Circle().stroke(Color.brand, lineWidth: filled ? 0 : 3)).frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.system(size: 12)).foregroundStyle(Color.muted)
                Text(value).font(.system(size: 19, weight: .bold)).foregroundStyle(Color.ink).opacity(alpha)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

/** 2장: 열차 점이 야탑 → 모란 → 태평으로 내려오고, 첫 줄을 누르면 골라진다. */
private struct BoardArt: View {
    let t: Double

    var body: some View {
        let picked = t > 2.2, tap = clamp((t - 2.2) / 0.5)
        ZStack(alignment: .topLeading) {
            Text("태평으로 들어오는 열차").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.muted).padding(.leading, 18).padding(.top, 14)
            Canvas { ctx, _ in
                let x = 72.0
                var p = Path(); p.move(to: CGPoint(x: x, y: 52)); p.addLine(to: CGPoint(x: x, y: 272))
                ctx.stroke(p, with: .color(suinBundang), lineWidth: 4)
                for y in [62.0, 162.0] {
                    ctx.fill(Path(ellipseIn: CGRect(x: x - 6, y: y - 6, width: 12, height: 12)), with: .color(.white))
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - 4.5, y: y - 4.5, width: 9, height: 9)), with: .color(suinBundang), lineWidth: 3)
                }
                ctx.fill(Path(ellipseIn: CGRect(x: x - 9, y: 253, width: 18, height: 18)), with: .color(.white))
                ctx.stroke(Path(ellipseIn: CGRect(x: x - 7.5, y: 254.5, width: 15, height: 15)), with: .color(.brand), lineWidth: 3)
                func train(_ y: Double, _ c: Color) {
                    ctx.fill(Path(roundedRect: CGRect(x: x - 10, y: y - 10, width: 20, height: 20), cornerRadius: 6), with: .color(.white))
                    ctx.fill(Path(roundedRect: CGRect(x: x - 8, y: y - 8, width: 16, height: 16), cornerRadius: 5), with: .color(c))
                }
                train(62 + 200 * ease(clamp(t / 2.2)), suinBundang)
                train(70 * ease(clamp(t / 3.6)), Color(hex: 0xC9D1E0))
            }
            .frame(width: 100, height: 316)
            Group {
                Text("야탑").font(.system(size: 13)).foregroundStyle(Color.muted).frame(width: 50, alignment: .trailing).offset(x: 10, y: 54)
                Text("모란").font(.system(size: 13)).foregroundStyle(Color.muted).frame(width: 50, alignment: .trailing).offset(x: 10, y: 154)
                Text("태평").font(.system(size: 14, weight: .black)).foregroundStyle(Color.brand).frame(width: 50, alignment: .trailing).offset(x: 10, y: 253)
            }
            VStack(spacing: 10) {
                row("8009", "태평 진입 · 지금 타세요", fg: picked ? .white : .ink, sub: picked ? .white.opacity(0.85) : .muted)
                    .background(picked ? suinBundang : .white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(picked ? suinBundang : Color.hairline, lineWidth: 2))
                    .overlay(
                        Circle().fill(.white.opacity(0.45 * (1 - tap))).frame(width: 120 * tap, height: 120 * tap)
                            .opacity(tap > 0 && tap < 1 ? 1 : 0).offset(x: 50),
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                row("8010", "[2]번째 전역 (야탑) · 약 4분", fg: .ink, sub: .muted)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.hairline, lineWidth: 2))
            }
            .frame(width: 206)
            .offset(x: 104, y: 60)
        }
        .frame(width: 326, height: 316, alignment: .topLeading)
        .guideCard()
    }

    private func row(_ no: String, _ status: String, fg: Color, sub: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .lastTextBaseline, spacing: 5) {
                Text(no).font(.system(size: 16, weight: .semibold))
                Text("왕십리행").font(.system(size: 15, weight: .heavy))
            }
            .foregroundStyle(fg)
            Text(status).font(.system(size: 12)).foregroundStyle(sub)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

/** 3장: 잠금화면 카드와 다이나믹 아일랜드의 역 이름이 바뀐다(iOS에서 실제로 뜨는 모습). */
private struct LockArt: View {
    let t: Double

    var body: some View {
        let names = ["가천대", "복정", "수서", "대모산입구"]
        let k = Int(t / 1.5) % names.count
        let fade = clamp((t.truncatingRemainder(dividingBy: 1.5) / 1.5) / 0.15)
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 36).fill(Color(hex: 0x0E1630))
            HStack {
                Circle().fill(suinBundang).frame(width: 10, height: 10)
                Spacer()
                Text(String(names[k].prefix(3))).font(.system(size: 11, weight: .bold)).foregroundStyle(.white).opacity(fade)
            }
            .padding(.horizontal, 10).frame(width: 100, height: 28).background(.black, in: Capsule()).padding(.top, 12)
            Text("18:12").font(.system(size: 46, weight: .light)).foregroundStyle(.white).padding(.top, 56)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("수").font(.system(size: 9, weight: .bold)).foregroundStyle(.white).frame(width: 14, height: 14).background(suinBundang, in: Circle())
                    Text("수인분당선 · 이번 정거장은").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.muted)
                }
                Text(names[k]).font(.system(size: 26, weight: .black)).foregroundStyle(Color.ink).opacity(fade)
                Text("강남까지 \(10 - k)정거장").font(.system(size: 13, weight: .bold)).foregroundStyle(Color(hex: 0x2A3348))
                GeometryReader { g in
                    Capsule().fill(Color.hairline)
                    Capsule().fill(Color.brand).frame(width: g.size.width * 0.09 * Double(k + 1))
                }
                .frame(height: 4).padding(.top, 4)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            .background(.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 18))
            .padding(.horizontal, 14).padding(.top, 150)
        }
        .frame(width: 240, height: 350)
        .shadow(color: Color(hex: 0x0A1E5A).opacity(0.3), radius: 16, y: 8)
    }
}

/** 4장: 갈아탈 역 한 정거장 전 알림이 내려오며 폰이 떤다. */
private struct AlertArt: View {
    let t: Double

    var body: some View {
        let drop = ease(clamp((t - 0.3) / 0.4))
        let shaking = t > 0.7 && t < 1.5
        ZStack {
            HStack {
                Image(systemName: "chevron.compact.left").font(.system(size: 34, weight: .bold))
                Spacer()
                Image(systemName: "chevron.compact.right").font(.system(size: 34, weight: .bold))
            }
            .foregroundStyle(.white.opacity(0.7)).frame(width: 320).opacity(shaking ? 1 : 0)
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 36).fill(.white)
                VStack(alignment: .leading, spacing: 10) {
                    Capsule().fill(Color(hex: 0xEEF1F6)).frame(width: 120, height: 14)
                    RoundedRectangle(cornerRadius: 14).fill(Color(hex: 0xEEF1F6)).frame(height: 90)
                    Capsule().fill(Color(hex: 0xEEF1F6)).frame(width: 170, height: 14)
                    Capsule().fill(Color(hex: 0xEEF1F6)).frame(width: 100, height: 14)
                }
                .padding(.horizontal, 14).padding(.top, 70)
                VStack(alignment: .leading, spacing: 2) {
                    Text("지금역 · 지금").font(.system(size: 11, weight: .bold)).foregroundStyle(Color(hex: 0x8A5A00))
                    Text("다음 역 선릉 · 2호선으로 갈아타세요").font(.system(size: 13, weight: .heavy)).lineLimit(1).minimumScaleFactor(0.8).foregroundStyle(Color.ink)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color(hex: 0xFFF4DC), in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: 0xF5D58A), lineWidth: 1))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                .padding(.horizontal, 10)
                .offset(y: -70 + 82 * drop)
            }
            .frame(width: 240, height: 350)
            .clipShape(RoundedRectangle(cornerRadius: 36))
            .shadow(color: Color(hex: 0x0A1E5A).opacity(0.3), radius: 16, y: 8)
            .offset(x: shaking ? sin(t * 70) * 3 : 0)
        }
    }
}
