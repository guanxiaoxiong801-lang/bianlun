import SwiftUI

/// 我的：账号（登录/注册/信息）+ 会员购买入口 + 管理员工具 + 后端设置。
struct ProfileView: View {
    @Binding var user: CurrentUser?
    @Binding var showPaywall: Bool
    var goCreate: () -> Void

    @State private var showLogin = false
    @State private var health: HealthInfo?
    @State private var baseURL = APIClient.shared.baseURL
    @State private var saved = false

    private let api = APIClient.shared

    var body: some View {
        NavigationStack {
            List {
                accountSection
                memberSection
                if user?.role == "admin" { adminSection }
                settingsSection
            }
            .navigationTitle("我的")
            .sheet(isPresented: $showLogin) {
                LoginView { newUser in
                    user = newUser
                }
            }
            .task { health = try? await api.health() }
        }
    }

    // MARK: 账号

    @ViewBuilder
    private var accountSection: some View {
        Section("账号") {
            if let u = user {
                HStack(spacing: 12) {
                    Text(String(u.username.prefix(1)).uppercased())
                        .font(.title2.bold())
                        .frame(width: 44, height: 44)
                        .background(Theme.accent.opacity(0.15))
                        .foregroundStyle(Theme.accent)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(u.username).font(.headline)
                        Text("\(u.usage.planName) · 本月 \(u.usage.casesThisMonth)/\(u.usage.casesLimit < 0 ? 999 : u.usage.casesLimit) 场")
                            .font(.caption)
                            .foregroundStyle(Theme.textSub)
                    }
                    Spacer()
                    if u.role == "admin" {
                        Text("管理员").font(.caption2.bold())
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Theme.accent.opacity(0.15))
                            .foregroundStyle(Theme.accent)
                            .cornerRadius(6)
                    }
                }
                Button("退出登录", role: .destructive) {
                    api.setAuth(token: nil, user: nil)
                    user = nil
                }
            } else {
                Button {
                    showLogin = true
                } label: {
                    Text("登录 / 注册")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                Text("登录后可创建辩论、查看历史与裁判意见书")
                    .font(.caption)
                    .foregroundStyle(Theme.textSub)
            }
        }
    }

    // MARK: 会员

    @ViewBuilder
    private var memberSection: some View {
        Section("会员与权益") {
            Button {
                showPaywall = true
            } label: {
                HStack {
                    Label("会员购买 / 升级", systemImage: "crown.fill")
                        .foregroundStyle(Theme.gold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.textSub)
                }
            }
            if let usage = user?.usage {
                Text("当前：\(usage.planName)（单场上限 \(usage.maxRounds) 轮）")
                    .font(.caption)
                    .foregroundStyle(Theme.textSub)
            }
        }
    }

    // MARK: 管理

    @ViewBuilder
    private var adminSection: some View {
        Section("管理员工具") {
            NavigationLink { AdminView() } label: {
                Label("模型启停与用量看板", systemImage: "slider.horizontal.3")
            }
        }
    }

    // MARK: 设置

    private var settingsSection: some View {
        Section("后端服务器") {
            TextField("https://…", text: $baseURL)
                .keyboardType(.URL)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            Button("保存并检测连接") {
                api.baseURL = baseURL
                Task {
                    health = try? await api.health()
                    saved = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { saved = false }
                }
            }
            if let health {
                Text(health.mockMode ? "已连接（Mock 演示模式）" : "已连接（真实模型在线）")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            if saved {
                Text("已保存").font(.caption).foregroundStyle(Theme.accent)
            }
        }
    }
}
