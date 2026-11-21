import SwiftUI
import UIKit

/** 스토어 등록정보·개인정보처리방침의 연락처와 같은 주소(삭제 요청도 이리로). */
private let contactEmail = "sinadsl1457@gmail.com"

/**
 * 설정(Android와 같은 줄): 알림(설정 앱으로), 사용법 다시 보기, 문의, 개인정보처리방침, 오픈소스 라이선스, 출처, 버전.
 * 개인정보처리방침은 서버와 같은 주소의 /privacy(주소를 코드에 따로 적지 않게).
 */
struct SettingsView: View {
    var onShowGuide: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    section("알림") {
                        // 알림 켜고 끄기·소리는 설정 앱에 맡긴다(앱 안 스위치를 따로 두면 어긋난다)
                        row("알림 설정", "잠금화면·내릴 역 알림 켜고 끄기, 소리", external: true) {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
                        }
                    }
                    section("도움말") {
                        row("사용법 다시 보기") {
                            dismiss()
                            onShowGuide()
                        }
                        divider
                        row("문의하기", "메일로 보내요. 탑승 기록 삭제 요청도 여기로", external: true) { openURL(mailURL) }
                    }
                    section("정보") {
                        row("개인정보처리방침", external: true) { openURL(APIClient.configuredBaseURL.appendingPathComponent("privacy")) }
                        divider
                        NavigationLink { LicensesView() } label: { label("오픈소스 라이선스", nil, external: false) }
                        divider
                        info("열차 위치 정보", "서울특별시 열린데이터광장 실시간 지하철 정보")
                        divider
                        HStack {
                            Text("버전").font(.system(size: 16, weight: .bold))
                            Spacer()
                            Text(version).font(.system(size: 15)).foregroundStyle(Color.muted)
                        }
                        .padding(.horizontal, 16).frame(minHeight: 56)
                    }
                    Text("열차 정보는 실제보다 30초~1분 늦을 수 있어요. 안내는 참고용이니 역 안내 방송도 함께 확인해 주세요.")
                        .font(.system(size: 12)).lineSpacing(4).foregroundStyle(Color.muted).padding(.horizontal, 4)
                }
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 20).padding(.vertical, 8)
            }
            .background(Color.ground)
            .navigationTitle("설정")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("닫기") { dismiss() } }
            }
        }
        // 앱은 홈 머리(파란색)의 상태 표시줄을 흰 글자로 하려고 다크로 두었다 → 밝은 바탕인 설정만 라이트로
        .preferredColorScheme(.light)
    }

    private var mailURL: URL {
        let device = UIDevice.current
        let body = "\n\n---\n앱 버전 \(version)\n기기 \(device.model) · iOS \(device.systemVersion)"
        var c = URLComponents()
        c.scheme = "mailto"
        c.path = contactEmail
        c.queryItems = [URLQueryItem(name: "subject", value: "[지금역 문의]"), URLQueryItem(name: "body", value: body)]
        return c.url ?? URL(string: "mailto:\(contactEmail)")!
    }

    private var divider: some View { Rectangle().fill(Color(hex: 0xEEF1F6)).frame(height: 1) }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted).padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func row(_ title: String, _ sub: String? = nil, external: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) { label(title, sub, external: external) }
    }

    private func label(_ title: String, _ sub: String?, external: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.ink)
                if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(Color.muted) }
            }
            Spacer()
            Image(systemName: external ? "arrow.up.right" : "chevron.right")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0x8A93A6))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minHeight: 56)
        .contentShape(Rectangle())
    }

    private func info(_ title: String, _ sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 16, weight: .bold))
            Text(sub).font(.system(size: 13)).foregroundStyle(Color.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

/** iOS 앱은 외부 라이브러리를 쓰지 않는다(애플 SDK만). */
private struct LicensesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("이 앱은 외부 오픈소스 라이브러리를 쓰지 않아요. Apple이 제공하는 SwiftUI·ActivityKit·Core Motion 등만 사용해요.")
                    .font(.system(size: 15)).lineSpacing(4).foregroundStyle(Color.ink)
                    .padding(16).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 16))
                Text("열차 위치 정보: 서울특별시 열린데이터광장 실시간 지하철 정보")
                    .font(.system(size: 13)).foregroundStyle(Color.muted).padding(.horizontal, 4)
            }
            .padding(20)
        }
        .background(Color.ground)
        .navigationTitle("오픈소스 라이선스")
        .navigationBarTitleDisplayMode(.inline)
    }
}
