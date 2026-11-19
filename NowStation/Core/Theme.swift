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

/**
 * 한 역의 노선 칩들. 칩 하나는 줄어들거나 줄바꿈하지 않는다(좁은 폰에서 "2/호/선"으로 깨지던 문제).
 * [maxWidth] 안에 다 들어가면 칩으로, 아니면 노선 색 점만 보여 준다(역 이름 자리를 먼저 지킨다).
 */
struct LineChips: View {
    let lines: [String]
    var maxWidth: CGFloat = 190

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) { ForEach(lines, id: \.self) { LineChip(line: $0) } }
            HStack(spacing: 5) {
                ForEach(lines, id: \.self) { Circle().fill(Color.line($0)).frame(width: 10, height: 10) }
            }
            .padding(.horizontal, 8).padding(.vertical, 7)
            .background(.white, in: Capsule())
            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(lines.joined(separator: ", "))
        }
        .frame(maxWidth: maxWidth, alignment: .trailing)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/** 흰 바탕 알약 + 노선 색 점(노랑·초록 바탕 흰 글씨는 안 읽혀서). */
struct LineChip: View {
    let line: String
    var onDark = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.line(line)).frame(width: 8, height: 8)
            Text(line).font(.system(size: 13, weight: .bold))
                .foregroundStyle(onDark ? Color.white : Color.ink)
                .lineLimit(1)
        }
        .fixedSize()
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(onDark ? Color.white.opacity(0.16) : Color.white, in: Capsule())
        .overlay(Capsule().stroke(onDark ? Color.clear : Color.hairline, lineWidth: 1))
    }
}
