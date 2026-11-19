import SwiftUI

/** 홈. 역 검색은 칸을 눌렀을 때만 덮어서 연다(첫 화면에 긴 목록을 깔지 않음). Android 홈과 같은 배치. */
struct HomeView: View {
    @Bindable var vm: HomeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Header()
                VStack(alignment: .leading, spacing: 24) {
                    HomeRouteCard(vm: vm)
                    if vm.recent.isEmpty { HowItWorks() } else { RecentRoutes(vm: vm) }
                    if !vm.lines.isEmpty { SupportedLines(lines: vm.lines) }
                    // 공공데이터 이용 조건: 출처 표시
                    Text("열차 위치: 서울특별시 열린데이터광장 실시간 지하철 정보")
                        .font(.caption2).foregroundStyle(Color.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 24)
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 20)
                .offset(y: -60)
                .padding(.bottom, -60)
            }
        }
        .background(Color.ground)
        .ignoresSafeArea(edges: .top)
        .fullScreenCover(isPresented: $vm.searching) { StationSearchView(vm: vm) }
        .alert(vm.message ?? "", isPresented: Binding(get: { vm.message != nil }, set: { if !$0 { vm.message = nil } })) {
            Button("확인", role: .cancel) {}
        }
        .task { await vm.load() }
    }
}

private struct Header: View {
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.brand
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 2)
                .frame(width: 240, height: 240).offset(x: 190, y: 60)
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 2)
                .frame(width: 150, height: 150).offset(x: 205, y: 125)
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("지금역").font(.system(size: 30, weight: .black)).foregroundStyle(.white)
                    Text("v\(version)").font(.caption.weight(.medium)).foregroundStyle(.white.opacity(0.7))
                }
                Text("타는 역과 내릴 역을 고르면, 탄 열차를 찾아\n잠금화면에 현재역을 보여 줘요")
                    .font(.system(size: 16)).foregroundStyle(.white.opacity(0.88))
                    .padding(.top, 6)
                TrackDecoration().frame(width: 250, height: 24).padding(.top, 22)
            }
            .padding(.horizontal, 24)
            .padding(.top, 76)
            .padding(.bottom, 92)
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
                step(1, "타는 역과 내릴 역을 고르고 탑승 시작")
                step(2, "열차에 타면 폰 움직임으로 탄 열차를 찾아요")
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
