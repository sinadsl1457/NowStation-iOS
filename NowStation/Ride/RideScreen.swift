import SwiftUI

/** 탑승 중. 내릴 역 직전이면 화면 전체를 파랑으로 바꿔 주머니에서 꺼냈을 때 바로 알아보게 한다. */
struct RideScreen: View {
    let ride: ActiveRide
    let onEnd: () -> Void
    // 끝내기는 되돌릴 수 없어서(현재역 표시·내릴 역 알림이 멈춤) 한 번 더 묻는다
    @State private var confirming = false

    var body: some View {
        ZStack {
            if ride.view.prepareToAlight {
                AlightContent(ride: ride, onEnd: { confirming = true })
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                RidingContent(ride: ride, onEnd: { confirming = true })
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
    let onEnd: () -> Void

    var body: some View {
        let v = ride.view
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if let line = v.line { LineChip(line: line) }
                Spacer()
                StatusPill(ride: ride)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(v.status == .waiting ? "기다리는 역" : v.thisStation == nil ? "위치 확인 중" : "이번 역")
                    .font(.system(size: 14, weight: .medium)).foregroundStyle(Color.muted)
                Text(v.thisStation ?? ride.origin)
                    .font(.system(size: 60, weight: .black)).minimumScaleFactor(0.5).lineLimit(1)
                Text(RideTexts.detail(ride)).font(.system(size: 16)).foregroundStyle(Color(hex: 0x2A3348))
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 24))

            RouteCard(ride: ride)

            Spacer()
            Label("화면을 꺼도 잠금화면에서 계속 보여요", systemImage: "lock")
                .font(.footnote).foregroundStyle(Color.muted).padding(.horizontal, 6)
            Button(action: onEnd) {
                Text("탑승 끝내기").font(.system(size: 16, weight: .bold)).foregroundStyle(Color(hex: 0x2A3348))
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .background(.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color(hex: 0xD5DCE8), lineWidth: 1))
            }
        }
        .foregroundStyle(Color.ink)
        .padding(.horizontal, 20).padding(.vertical, 16)
        .background(Color.ground)
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
            Text("내릴 준비하세요").font(.system(size: 30, weight: .black)).padding(.top, 18)
            Text("이번 역").font(.system(size: 16)).opacity(0.85).padding(.top, 10)
            Text(v.thisStation ?? "").font(.system(size: 76, weight: .black))
                .scaleEffect(grown ? 1 : 0.85)
            Text("내리실 역이에요").font(.system(size: 16)).opacity(0.9)
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
