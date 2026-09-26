import SwiftUI

/// 管理员工具：管理员令牌 → 模型启停 + 用量看板。
struct AdminView: View {
    @AppStorage("dh.adminToken") private var token = ""
    @State private var entries: [AdminRegistryEntry] = []
    @State private var usage: AdminUsage?
    @State private var authed = false
    @State private var error = ""
    @State private var busy = false
    @State private var notice = ""

    private let api = APIClient.shared

    var body: some View {
        Group {
            if authed {
                content
            } else {
                Form {
                    Section("管理员登录（ADMIN_TOKEN）") {
                        SecureField("ADMIN_TOKEN", text: $token)
                            .textInputAutocapitalization(.never)
                        Button("进入") { Task { await load() } }
                            .disabled(token.isEmpty || busy)
                    }
                    if !error.isEmpty {
                        Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) }
                    }
                }
                .navigationTitle("管理")
            }
        }
        .navigationTitle("管理")
        .onAppear { if !token.isEmpty { Task { await load() } } }
    }

    private var content: some View {
        List {
            Section {
                Button {
                    Task { await load() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
            }
            Section("模型管理（启停立即生效）") {
                ForEach(entries) { m in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(m.preset).font(.subheadline.bold())
                            Text("\(m.vendor) / \(m.modelName)")
                                .font(.caption).foregroundStyle(Theme.textSub)
                        }
                        Spacer()
                        Text(m.available ? "可用" : "不可用")
                            .font(.caption2)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(m.available ? Theme.accent.opacity(0.15) : Theme.line.opacity(0.4))
                            .cornerRadius(5)
                        Toggle("", isOn: Binding(
                            get: { m.enabled },
                            set: { newValue in Task { await toggle(m.preset, to: newValue) } }))
                            .labelsHidden()
                    }
                }
            }
            if let usage {
                Section("用量与成本") {
                    LabeledContent("调用次数", value: "\(usage.overview.calls)")
                    LabeledContent("Mock 调用", value: "\(usage.overview.mockCalls)")
                    LabeledContent("总成本", value: "$\(String(format: "%.4f", usage.overview.totalCostUsd))")
                    ForEach(Array(usage.byModel.keys.sorted()), id: \.self) { key in
                        if let row = usage.byModel[key] {
                            LabeledContent(key, value: "$\(String(format: "%.4f", row.costUsd)) · \(row.calls) 次")
                        }
                    }
                }
            }
            Section {
                Button("退出管理登录", role: .destructive) {
                    token = ""
                    authed = false
                    entries = []
                    usage = nil
                }
            }
        }
    }

    private func load() async {
        busy = true
        error = ""
        do {
            entries = try await api.adminRegistry().models
            usage = try? await api.adminUsage()
            authed = true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "加载失败"
        }
        busy = false
    }

    private func toggle(_ preset: String, to enabled: Bool) async {
        do {
            try await api.adminToggleModel(preset: preset, enabled: enabled)
            notice = "已\(enabled ? "启用" : "停用")"
            await load()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "操作失败"
        }
    }
}
