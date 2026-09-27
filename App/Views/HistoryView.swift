import SwiftUI

/// 历史辩论列表（商用模式下按归属过滤；点击进入辩论/意见书）。
struct HistoryView: View {
    @State private var cases: [CaseDetail] = []
    @State private var loading = true
    @State private var error = ""

    var body: some View {
        NavigationStack {
            Group {
                if loading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if !error.isEmpty {
                    VStack(spacing: 8) {
                        Text(error).font(.footnote).foregroundStyle(Theme.danger)
                        Text("提示：登录后可见属于你的辩论记录")
                            .font(.caption)
                            .foregroundStyle(Theme.textSub)
                    }
                } else if cases.isEmpty {
                    VStack(spacing: 6) {
                        Text("还没有辩论记录").font(.headline).foregroundStyle(Theme.textMain)
                        Text("去「发起」创建第一场辩论").font(.caption).foregroundStyle(Theme.textSub)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(cases) { c in
                            NavigationLink { DebateView(caseId: c.caseId) } label: {
                                HistoryRow(detail: c)
                            }
                            .listRowBackground(Theme.card)
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background)
            .navigationTitle("历史")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        loading = cases.isEmpty
        error = ""
        do {
            cases = try await APIClient.shared.listCases()
                .sorted { $0.caseId > $1.caseId }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "加载失败"
        }
        loading = false
    }
}

private struct HistoryRow: View {
    let detail: CaseDetail

    private var statusLabel: (String, Color) {
        switch detail.status {
        case "completed": return ("已结案", Theme.accent)
        case "running": return ("进行中", Theme.gold)
        case "error": return ("中断", Theme.danger)
        default: return ("待开始", Theme.textSub)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(detail.title).font(.subheadline.bold()).lineLimit(1)
                    .foregroundStyle(Theme.textMain)
                Spacer()
                Text(statusLabel.0).font(.caption2).foregroundStyle(statusLabel.1)
            }
            Text(detail.scenario + " · \(detail.maxRounds) 轮 · 步骤 \(detail.stepIndex)")
                .font(.caption2)
                .foregroundStyle(Theme.textSub)
        }
        .padding(.vertical, 4)
    }
}
