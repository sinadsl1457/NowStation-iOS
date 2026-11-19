import SwiftUI

/** Android 앱과 같은 색(파랑 #1F4FD8). */
extension Color {
    static let brand = Color(hex: 0x1F4FD8)
    static let brandTint = Color(hex: 0xEAF0FF)
    static let ground = Color(hex: 0xF4F7FC)
    static let ink = Color(hex: 0x141B2D)
    static let muted = Color(hex: 0x5A6478)
    static let hairline = Color(hex: 0xE3E8F2)
    static let fieldFill = Color(hex: 0xF1F4FA)

    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /** 노선 색. 서버가 주는 표시 이름(2호선, 수인분당선, 신분당선)으로 고른다. */
    static func line(_ name: String?) -> Color {
        switch name {
        case "2호선": return Color(hex: 0x00A84D)
        case "수인분당선": return Color(hex: 0xF5A200)
        case "신분당선": return Color(hex: 0xD4003B)
        default: return .muted
        }
    }
}

/** 배지에 넣을 짧은 기호: "2호선" → "2", 그 밖의 노선은 첫 글자(수인분당선 → 수, 신분당선 → 신). */
func lineSymbol(_ line: String) -> String {
    if line.hasSuffix("호선"), let n = Int(line.dropLast(2)) { return String(n) }
    return String(line.prefix(1))
}

/**
 * 노선 배지: 노선색으로 채운 원 + 흰 기호. 폭이 모두 같아서 노선이 늘어도 자리를 미리 안다
 * (이름 칩은 노선 이름 길이만큼 늘어 좁은 폰에서 깨졌다). 화면 읽기는 노선 이름으로 읽는다.
 */
struct LineBadge: View {
    let line: String
    var size: CGFloat = 24

    var body: some View {
        let symbol = lineSymbol(line)
        Text(symbol)
            .font(.system(size: symbol.first?.isNumber == true ? 13 : 12, weight: .heavy))
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(width: size, height: size)
            .background(Color.line(line), in: Circle())
            .accessibilityLabel(line)
    }
}

/** 한 역의 노선들(홈 카드·역 검색). 배지만, [max]개를 넘으면 "+N". */
struct LineBadges: View {
    let lines: [String]
    var max = 4

    var body: some View {
        HStack(spacing: 4) {
            ForEach(lines.prefix(max), id: \.self) { LineBadge(line: $0) }
            if lines.count > max {
                Text("+\(lines.count - max)").font(.system(size: 12, weight: .bold)).foregroundStyle(Color.muted)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color(hex: 0xEEF1F6), in: Capsule())
            }
        }
        .fixedSize()
    }
}

/** 노선 하나를 이름까지(탑승 화면 위쪽처럼 자리가 넉넉한 곳): 배지 + 노선 이름. onDark: 파란 배경 위. */
struct LineChip: View {
    let line: String
    var onDark = false

    var body: some View {
        HStack(spacing: 8) {
            LineBadge(line: line, size: 22).accessibilityHidden(true)
            Text(line).font(.system(size: 14, weight: .bold))
                .foregroundStyle(onDark ? Color.white : Color.ink)
                .lineLimit(1)
        }
        .fixedSize()
        .padding(.leading, 4).padding(.trailing, 12).padding(.vertical, 4)
        .background(onDark ? Color.white.opacity(0.16) : Color.white, in: Capsule())
        .overlay(Capsule().stroke(onDark ? Color.clear : Color.hairline, lineWidth: 1))
    }
}
