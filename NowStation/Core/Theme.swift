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

/** 흰 바탕 알약 + 노선 색 점(노랑·초록 바탕 흰 글씨는 안 읽혀서). */
struct LineChip: View {
    let line: String
    var onDark = false

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.line(line)).frame(width: 8, height: 8)
            Text(line).font(.system(size: 13, weight: .bold))
                .foregroundStyle(onDark ? Color.white : Color.ink)
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(onDark ? Color.white.opacity(0.16) : Color.white, in: Capsule())
        .overlay(Capsule().stroke(onDark ? Color.clear : Color.hairline, lineWidth: 1))
    }
}
