import SwiftUI

@main
struct DebateHubApp: App {
    init() {
        // App 启动即探测可用后端（局域网优先，公网隧道兜底）
        Task { await APIClient.shared.resolveBestBaseURL() }
    }
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// 根视图：底部四 Tab（场景 / 发起 / 历史 / 我的）。
/// 管理与会员入口收纳在「我的」。
struct RootView: View {
    @State private var tab: Tab = .scenes
    @State private var user: CurrentUser?
    @State private var showPaywall = false
    private let api = APIClient.shared

    enum Tab: String, Hashable {
        case scenes = "场景"
        case create = "发起"
        case history = "历史"
        case profile = "我的"
    }

    var body: some View {
        TabView(selection: $tab) {
            ScenesView(goCreate: { tab = .create }, user: $user, showPaywall: $showPaywall)
                .tabItem { Label("场景", systemImage: "square.grid.2x2") }
                .tag(Tab.scenes)
            CreateCaseView(user: user)
                .tabItem { Label("发起", systemImage: "plus.bubble") }
                .tag(Tab.create)
            HistoryView()
                .tabItem { Label("历史", systemImage: "clock.arrow.circlepath") }
                .tag(Tab.history)
            ProfileView(user: $user, showPaywall: $showPaywall, goCreate: { tab = .create })
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
                .tag(Tab.profile)
        }
        .tint(Theme.accent)
        .sheet(isPresented: $showPaywall) { PaywallView() }
        .task { user = api.savedUser() }
    }
}
