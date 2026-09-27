import SwiftUI

/// 发起辩论：场景预选 + 辩题/立场 + 轮次 + 正反方模型选择，创建后进入辩论直播。
struct CreateCaseView: View {
    var preselected: ScenarioInfo?
    var user: CurrentUser?

    @State private var scenarios: [ScenarioInfo] = []
    @State private var scenarioId = "legal"
    @State private var title = ""
    @State private var description = ""
    @State private var plaintiffSide = ""
    @State private var defendantSide = ""
    @State private var maxRounds = 3
    @State private var models: [ModelInfo] = []
    @State private var modelsLoaded = false
    @State private var plaintiffModel: String?
    @State private var defendantModel: String?
    @State private var submitting = false
    @State private var error = ""
    @State private var doneCaseId: String?
    @State private var pushDebate = false

    private let api = APIClient.shared

    private var canSubmit: Bool {
        !submitting && !title.trimmingCharacters(in: .whitespaces).isEmpty
            && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        Form {
            Section("场景") {
                Picker("场景", selection: $scenarioId) {
                    ForEach(scenarios) { s in
                        Text(s.name).tag(s.scenarioId)
                    }
                }
                if let s = scenarios.first(where: { $0.scenarioId == scenarioId }) {
                    Text(s.description).font(.caption).foregroundStyle(Theme.textSub)
                }
            }
            Section("辩题") {
                TextField("例如：公司单方解除劳动合同是否合法", text: $title)
                TextField("背景描述（事实经过、争议起因）", text: $description, axis: .vertical)
                    .lineLimit(3...5)
            }
            Section("双方立场") {
                TextField("正方立场（必填）", text: $plaintiffSide)
                TextField("反方立场（选填，可由 AI 归纳）", text: $defendantSide)
            }
            Section("深度") {
                Stepper("辩论轮次：\(maxRounds) 轮", value: $maxRounds, in: 1...9)
                if let usage = user?.usage, maxRounds > usage.maxRounds {
                    Label("当前套餐单场上限 \(usage.maxRounds) 轮，超额轮次将被钳制",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(Theme.gold)
                }
            }
            Section("辩论模型") {
                    Picker("正方模型", selection: $plaintiffModel) {
                        Text("自动（服务端路由）").tag(String?.none)
                        ForEach(models) { m in
                            Text("\(m.modelName)").tag(String?.some(m.preset))
                        }
                    }
                    Picker("反方模型", selection: $defendantModel) {
                        Text("自动（服务端路由）").tag(String?.none)
                        ForEach(models) { m in
                            Text("\(m.modelName)").tag(String?.some(m.preset))
                        }
                    }
                    Text("正反方可接不同模型对辩；裁判团由服务端异构路由")
                        .font(.caption)
                        .foregroundStyle(Theme.textSub)
            }
            Section {
                Button {
                    Task { await submit() }
                } label: {
                    HStack {
                        Spacer()
                        if submitting { ProgressView().tint(Theme.background) }
                        else { Text("创建并进入辩论").bold() }
                        Spacer()
                    }
                }
                .listRowBackground(canSubmit ? Theme.accent : Theme.line)
                .disabled(!canSubmit)
            }
            if !error.isEmpty {
                Section {
                    Text(error).foregroundStyle(Theme.danger).font(.footnote)
                    if error.contains("登录") || error.contains("额度") {
                        NavigationLink("去处理 →") { PaywallView() }
                    }
                }
            }
        }
        .hideKeyboardOnTap()
        .navigationTitle("发起辩论")
        .task { await loadAll() }
        .navigationDestination(isPresented: $pushDebate) {
            DebateView(caseId: doneCaseId ?? "")
        }
    }

    private func loadAll() async {
        scenarios = (try? await api.scenarios()) ?? []
        if let pre = preselected { scenarioId = pre.scenarioId }
        await loadModels()
    }

    private func loadModels() async {
        // 内置模型清单（不依赖网络接口；服务端注册表已含同名 preset，路由可用）
        let builtin: [ModelInfo] = [
            ModelInfo(preset: "gpt-luna", kind: "custom", vendor: "custom",
                      modelName: "gpt-5.6-luna（轻量·最快最省）", enabled: true,
                      available: true, promptPer1kUsd: 0.000044,
                      completionPer1kUsd: 0.000264, description: "极致性价比"),
            ModelInfo(preset: "gpt-terra", kind: "custom", vendor: "custom",
                      modelName: "gpt-5.6-terra（平衡）", enabled: true,
                      available: true, promptPer1kUsd: 0.00044,
                      completionPer1kUsd: 0.00264, description: "平衡质量与成本"),
            ModelInfo(preset: "gpt-54mini", kind: "custom", vendor: "custom",
                      modelName: "gpt-5.4-mini（轻快）", enabled: true,
                      available: true, promptPer1kUsd: 0.000165,
                      completionPer1kUsd: 0.00099, description: "轻量快速"),
            ModelInfo(preset: "gpt-54", kind: "custom", vendor: "custom",
                      modelName: "gpt-5.4（长文本）", enabled: true,
                      available: true, promptPer1kUsd: 0.00055,
                      completionPer1kUsd: 0.0033, description: "1M 超长上下文"),
            ModelInfo(preset: "gpt-55", kind: "custom", vendor: "custom",
                      modelName: "gpt-5.5（旗舰）", enabled: true,
                      available: true, promptPer1kUsd: 0.0011,
                      completionPer1kUsd: 0.0066, description: "综合能力最强"),
            ModelInfo(preset: "gpt-sol", kind: "custom", vendor: "custom",
                      modelName: "gpt-5.6-sol（顶级质量）", enabled: true,
                      available: true, promptPer1kUsd: 0.0011,
                      completionPer1kUsd: 0.0066, description: "极致质量要求"),
        ]
        // 在线拉取成功则用服务端列表；失败回落到内置清单（永不空）
        if let remote = try? await api.models().filter({ $0.enabled && $0.available }),
           !remote.isEmpty {
            models = remote
        } else {
            models = builtin
        }
        modelsLoaded = true
    }

    private func submit() async {
        error = ""
        submitting = true
        defer { submitting = false }
        do {
            // 正反方各自模型 → per-role 覆盖；选“自动”的一方走服务端路由
            var override: [String: Any]?
            if plaintiffModel != nil || defendantModel != nil {
                var roles: [String: Any] = [:]
                if let pm = plaintiffModel { roles["plaintiff"] = ["primary": pm] }
                if let dm = defendantModel { roles["defendant"] = ["primary": dm] }
                override = roles
            }
            doneCaseId = try await api.createCase(
                title: title.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                scenario: scenarioId,
                plaintiffSide: plaintiffSide.trimmingCharacters(in: .whitespaces).isEmpty
                    ? "正方立场（可在描述中补充）" : plaintiffSide.trimmingCharacters(in: .whitespaces),
                defendantSide: defendantSide.trimmingCharacters(in: .whitespaces).isEmpty
                    ? nil : defendantSide.trimmingCharacters(in: .whitespaces),
                maxRounds: maxRounds,
                modelOverride: override)
            pushDebate = true
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "创建失败"
        }
    }
}
