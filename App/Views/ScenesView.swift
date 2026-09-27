import SwiftUI

/// 首页：账号状态/剩余额度速览 + 场景网格（点击进入发起页并预选场景）。
struct ScenesView: View {
    var goCreate: () -> Void
    @Binding var user: CurrentUser?
    @Binding var showPaywall: Bool

    @State private var scenarios: [ScenarioInfo] = []
    @State private var health: HealthInfo?
    @State private var loadError = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    greeting
                    quotaCard
                    Text("选择一个场景开始")
                        .font(.headline)
                        .foregroundStyle(Theme.textMain)
                    if !loadError.isEmpty {
                        Text(loadError)
                            .font(.footnote)
                            .foregroundStyle(Theme.danger)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(scenarios) { s in
                            NavigationLink(value: s) {
                                ScenarioCard(info: s)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("辩坛 AI")
            .navigationDestination(for: ScenarioInfo.self) { s in
                CreateCaseView(preselected: s, user: user)
            }
        }
        .task {
            async let sc = try? APIClient.shared.scenarios()
            async let h = try? APIClient.shared.health()
            scenarios = (await sc) ?? []
            health = await h
            if scenarios.isEmpty && health == nil {
                loadError = "无法连接后端：请在「我的 → 设置」检查服务器地址"
            }
        }
        .refreshable {
            user = try? await APIClient.shared.me()
        }
    }

    private var greeting: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(user.map { "你好，\($0.username)" } ?? "欢迎来到辩坛")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.textMain)
                Text(health.map { $0.mockMode ? "Mock 演示模式" : "真实模型在线" } ?? "连接中…")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSub)
            }
            Spacer()
            NavigationLink { PaywallView() } label: {
                Text(user?.usage.plan.uppercased() ?? "会员")
                    .font(.caption.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.15))
                    .foregroundStyle(Theme.accent)
                    .cornerRadius(8)
            }
        }
    }

    @ViewBuilder
    private var quotaCard: some View {
        if let usage = user?.usage {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(usage.planName) · 本月额度")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSub)
                    Text(usage.casesLimit < 0
                         ? "已建 \(usage.casesThisMonth) 场（不限）"
                         : "已用 \(usage.casesThisMonth)/\(usage.casesLimit) 场")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textMain)
                }
                Spacer()
                Button("升级") { showPaywall = true }
                    .font(.footnote.bold())
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            }
            .padding(12)
            .background(Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
        }
    }

    private func showPaywallRoute() {
        NotificationCenter.default.post(name: .openPaywall, object: nil)
    }
}

private struct ScenarioCard: View {
    let info: ScenarioInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(info.name)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.textMain)
            Text(info.description)
                .font(.caption2)
                .foregroundStyle(Theme.textSub)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            HStack(spacing: 6) {
                Label("\(info.judgePanelSize) 裁判", systemImage: "person.2")
                if info.kbEnabled { Label("法条RAG", systemImage: "doc.text.magnifyingglass") }
            }
            .font(.system(size: 9))
            .foregroundStyle(Theme.accent)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}
