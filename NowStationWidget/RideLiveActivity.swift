import ActivityKit
import SwiftUI
import WidgetKit

@main
struct NowStationWidgetBundle: WidgetBundle {
    var body: some Widget {
        RideLiveActivity()
    }
}

/** 잠금화면과 다이나믹 아일랜드. 문구는 앱이 만들어 넣고 여기는 그리기만 한다. */
struct RideLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RideActivityAttributes.self) { context in
            LockScreenView(state: context.state, attributes: context.attributes)
                .activityBackgroundTint(context.state.prepareToAlight ? Color.brand : Color.white)
                .activitySystemActionForegroundColor(context.state.prepareToAlight ? .white : Color.brand)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    if let line = s.line { LineDotLabel(line: line) }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if !s.online { Image(systemName: "wifi.slash").foregroundStyle(.secondary) }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.title).font(.title3.weight(.bold))
                            .foregroundStyle(s.prepareToAlight ? Color.yellow : .white)
                        Text(s.detail).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                if let n = s.remaining, !s.prepareToAlight {
                    // 남은 정거장 수(이번정거장처럼). 숫자가 줄어드는 게 한눈에 보이게
                    Text("\(n)").font(.caption.weight(.heavy)).foregroundStyle(.white)
                        .frame(width: 22, height: 22).background(Circle().stroke(Color.line(s.line), lineWidth: 2.5))
                } else {
                    Image(systemName: s.prepareToAlight ? "flag.fill" : "tram.fill")
                        .foregroundStyle(s.prepareToAlight ? Color.yellow : Color.line(s.line))
                }
            } compactTrailing: {
                Text(s.chip ?? "…").font(.caption.weight(.bold)).lineLimit(1)
            } minimal: {
                Image(systemName: s.prepareToAlight ? "flag.fill" : "tram.fill")
                    .foregroundStyle(s.prepareToAlight ? Color.yellow : Color.line(s.line))
            }
        }
    }
}

private struct LineDotLabel: View {
    let line: String
    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.line(line)).frame(width: 8, height: 8)
            Text(line).font(.caption.weight(.bold))
        }
    }
}

private struct LockScreenView: View {
    let state: RideActivityAttributes.ContentState
    let attributes: RideActivityAttributes

    var body: some View {
        let onBrand = state.prepareToAlight
        HStack(spacing: 14) {
            Image(systemName: onBrand ? "flag.fill" : "tram.fill")
                .font(.system(size: 20))
                .foregroundStyle(onBrand ? Color.brand : .white)
                .frame(width: 44, height: 44)
                .background(onBrand ? Color.white : Color.brand, in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    if let line = state.line {
                        Circle().fill(Color.line(line)).frame(width: 8, height: 8)
                        Text(line).font(.caption.weight(.bold))
                    }
                    if let d = attributes.destination { Text("· \(d)까지").font(.caption) }
                }
                .opacity(0.8)
                Text(state.title).font(.system(size: 19, weight: .black)).lineLimit(1)
                Text(state.detail).font(.subheadline).opacity(0.8).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(onBrand ? Color.white : Color.ink)
        .padding(16)
    }
}
