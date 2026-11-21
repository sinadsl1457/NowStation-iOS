import SwiftUI
import UIKit
import UserNotifications
import WebKit

/**
 * 설정(Android와 같은 줄). 모두 앱 안에서: 알림 스위치, 사용법 다시 보기, 문의하기(서버로 보냄),
 * 개인정보처리방침(웹뷰, 서버 /privacy), 오픈소스 라이선스, 출처, 버전.
 */
struct SettingsView: View {
    var onShowGuide: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var prefs = AlertSettings.current
    @State private var path: [Page] = []

    enum Page: Hashable { case contact, privacy, licenses }

    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        section("알림") {
                            NotificationPermissionRow()
                            toggle("갈아타기 알림", "갈아탈 역 한 정거장 전에 알려 줘요", $prefs.transfer)
                            divider
                            toggle("내릴 역 알림", "내릴 역 한 정거장 전에 알려 줘요", $prefs.alight)
                            divider
                            toggle("진동", "위 알림 때 진동", $prefs.vibrate, enabled: prefs.transfer || prefs.alight)
                        }
                        Text("잠금화면·다이나믹 아일랜드의 현재역 표시는 탑승을 끝내면 사라져요.")
                            .font(.system(size: 12)).foregroundStyle(Color.muted).padding(.horizontal, 4)
                    }
                    section("도움말") {
                        row("사용법 다시 보기") {
                            dismiss()
                            onShowGuide()
                        }
                        divider
                        row("문의하기", "궁금한 점, 오류, 탑승 기록 삭제 요청") { path.append(.contact) }
                    }
                    section("정보") {
                        row("개인정보처리방침") { path.append(.privacy) }
                        divider
                        row("오픈소스 라이선스") { path.append(.licenses) }
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
            .navigationDestination(for: Page.self) { page in
                switch page {
                case .contact: ContactView()
                case .privacy: PrivacyView { path = [.contact] }
                case .licenses: LicensesView()
                }
            }
        }
        .onChange(of: prefs) { _, new in AlertSettings.current = new }
        // 앱은 홈 머리(파란색)의 상태 표시줄을 흰 글자로 하려고 다크로 두었다 → 밝은 바탕인 설정만 라이트로
        .preferredColorScheme(.light)
    }

    private var divider: some View { Rectangle().fill(Color(hex: 0xEEF1F6)).frame(height: 1) }

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted).padding(.horizontal, 4)
            VStack(spacing: 0) { content() }
                .background(.white, in: RoundedRectangle(cornerRadius: 16))
        }
    }

    private func row(_ title: String, _ sub: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(Color.ink)
                    if let sub { Text(sub).font(.system(size: 13)).foregroundStyle(Color.muted) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(hex: 0x8A93A6))
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
    }

    private func toggle(_ title: String, _ sub: String, _ on: Binding<Bool>, enabled: Bool = true) -> some View {
        Toggle(isOn: Binding(get: { on.wrappedValue && enabled }, set: { on.wrappedValue = $0 })) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .bold)).foregroundStyle(enabled ? Color.ink : Color(hex: 0x8A93A6))
                Text(sub).font(.system(size: 13)).foregroundStyle(Color.muted)
            }
        }
        .tint(Color.brand)
        .disabled(!enabled)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .frame(minHeight: 64)
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

/** 알림이 꺼져 있으면 그 자리에서 허용을 묻는다. 이미 거절했으면 iOS는 다시 묻지 못해서 그때만 설정 앱으로. */
private struct NotificationPermissionRow: View {
    @State private var status: UNAuthorizationStatus = .authorized
    @Environment(\.scenePhase) private var phase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Group {
            if status == .notDetermined || status == .denied {
                VStack(alignment: .leading, spacing: 8) {
                    Text("알림이 꺼져 있어요").font(.system(size: 15, weight: .bold))
                    Text("갈아타기·내릴 역 알림을 받으려면 알림을 허용해 주세요.").font(.system(size: 13)).foregroundStyle(Color(hex: 0x5A4A1E))
                    Button {
                        if status == .notDetermined {
                            Task {
                                _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                                await refresh()
                            }
                        } else if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        Text("알림 허용").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 16).frame(minHeight: 40)
                            .background(Color.brand, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 12)
                .background(Color(hex: 0xFFF4DC))
                Rectangle().fill(Color(hex: 0xEEF1F6)).frame(height: 1)
            }
        }
        .task { await refresh() }
        .onChange(of: phase) { _, p in if p == .active { Task { await refresh() } } }
    }

    private func refresh() async {
        status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}

private struct FeedbackRequest: Encodable {
    let message: String
    let contact: String?
    let platform: String
    let appVersion: String
    let device: String
}

/** 앱 안 문의하기: 글과(선택) 답장 이메일을 서버로. 메일 앱을 열지 않는다. */
private struct ContactView: View {
    @State private var message = ""
    @State private var contact = ""
    @State private var sending = false
    @State private var sent = false
    @State private var error: String?

    private static let maxMessage = 2000
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "" }
    private var contactInvalid: Bool {
        let c = contact.trimmingCharacters(in: .whitespaces)
        return !c.isEmpty && c.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]+$"#, options: .regularExpression) == nil
    }
    private var canSend: Bool { !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sending && !contactInvalid }

    var body: some View {
        Group {
            if sent {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 56)).foregroundStyle(Color.brand)
                    Text("보냈어요").font(.system(size: 22, weight: .black))
                    Text(contact.isEmpty ? "보내 주셔서 고마워요." : "적어 주신 이메일로 답장 드릴게요.").font(.system(size: 15)).foregroundStyle(Color.muted)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("내용").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted)
                            TextEditor(text: $message)
                                .frame(minHeight: 180)
                                .padding(8)
                                .scrollContentBackground(.hidden)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topLeading) {
                                    if message.isEmpty {
                                        Text("궁금한 점이나 불편한 점을 적어 주세요. 탑승 기록 삭제를 원하면 탑승한 날짜와 시각을 적어 주세요.")
                                            .font(.system(size: 15)).foregroundStyle(Color(hex: 0xA8B0BF))
                                            .padding(.horizontal, 13).padding(.vertical, 16).allowsHitTesting(false)
                                    }
                                }
                                .accessibilityIdentifier("contact-message")
                                .onChange(of: message) { _, v in if v.count > Self.maxMessage { message = String(v.prefix(Self.maxMessage)) } }
                            Text("\(message.count) / \(Self.maxMessage)").font(.system(size: 12)).foregroundStyle(Color.muted)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text("답장받을 이메일(선택)").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.muted)
                            TextField("me@example.com", text: $contact)
                                .keyboardType(.emailAddress).textInputAutocapitalization(.never).autocorrectionDisabled()
                                .padding(12)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                            Text(contactInvalid ? "이메일 모양이 아니에요" : "적지 않으면 답장 없이 확인만 해요")
                                .font(.system(size: 12)).foregroundStyle(contactInvalid ? .red : Color.muted)
                        }
                        Text("앱 버전(\(version))과 기기 종류가 함께 가요. 문의는 1년 뒤 지워요.").font(.system(size: 12)).foregroundStyle(Color.muted)
                        if let error { Text(error).font(.system(size: 14)).foregroundStyle(.red) }
                        Button { Task { await send() } } label: {
                            Group {
                                if sending { ProgressView().tint(.white) } else { Text("보내기").font(.system(size: 17, weight: .bold)) }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(canSend ? Color.brand : Color(hex: 0xC9D1E0), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .disabled(!canSend)
                    }
                    .padding(20)
                }
            }
        }
        .foregroundStyle(Color.ink)
        .background(Color.ground)
        .navigationTitle("문의하기")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func send() async {
        sending = true
        error = nil
        let c = contact.trimmingCharacters(in: .whitespaces)
        let request = FeedbackRequest(
            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
            contact: c.isEmpty ? nil : c,
            platform: "ios",
            appVersion: version,
            device: "\(UIDevice.current.model) · iOS \(UIDevice.current.systemVersion)"
        )
        do {
            try await APIClient().postNoContent("api/feedback", body: request)
            sent = true
        } catch APIError.network {
            error = "서버에 연결할 수 없어요. 잠시 뒤 다시 보내 주세요"
        } catch {
            self.error = "보내지 못했어요. 잠시 뒤 다시 보내 주세요"
        }
        sending = false
    }
}

/** 개인정보처리방침: 서버의 /privacy를 앱 안 웹뷰로. 메일 링크는 앱 안 문의하기로 돌린다. */
private struct PrivacyView: View {
    var onContact: () -> Void
    @State private var loading = true
    @State private var failed = false
    @State private var reload = 0

    var body: some View {
        ZStack {
            WebView(url: APIClient.configuredBaseURL.appendingPathComponent("privacy"), reload: reload, loading: $loading, failed: $failed, onMail: onContact)
            if loading { ProgressView() }
            if failed {
                VStack(spacing: 8) {
                    Text("불러오지 못했어요").font(.system(size: 18, weight: .bold))
                    Text("인터넷 연결을 확인하고 다시 시도해 주세요.").font(.system(size: 14)).foregroundStyle(Color.muted)
                    Button("다시 시도") { reload += 1 }.font(.system(size: 15, weight: .bold)).tint(Color.brand).padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white)
            }
        }
        .navigationTitle("개인정보처리방침")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebView: UIViewRepresentable {
    let url: URL
    let reload: Int
    @Binding var loading: Bool
    @Binding var failed: Bool
    let onMail: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loaded != reload {
            context.coordinator.loaded = reload
            view.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebView
        var loaded = -1
        init(_ parent: WebView) { self.parent = parent }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if action.request.url?.scheme == "mailto" {
                parent.onMail()
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.loading = true
            parent.failed = false
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { parent.loading = false }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.loading = false
            parent.failed = true
        }
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
