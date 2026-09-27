import SwiftUI

/// 会员购买 / 升级（支付通道接入前的额度制：显示套餐与权益，联系管理员开通）。
struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var plans: [PlanInfo] = []
    @State private var currentPlan: String?
    @State private var loading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    hero
                    ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                        PlanCard(plan: plan, isCurrent: plan.plan == currentPlan,
                                 highlighted: index == 2)
                    }
                    notice
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("会员")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } } }
            .task {
                plans = (try? await APIClient.shared.plans()) ?? []
                currentPlan = APIClient.shared.savedUser()?.usage.plan
                loading = false
            }
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill").foregroundStyle(Theme.gold)
                Text("辩坛会员").font(.title2.bold()).foregroundStyle(Theme.textMain)
            }
            Text("解锁更多场次与更深度的多 Agent 对抗：三裁判合议、法条 RAG 举证、结构化判决书。")
                .font(.footnote)
                .foregroundStyle(Theme.textSub)
        }
        .padding(.top, 4)
    }

    private var notice: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("· 支付通道接入中：内测期间联系管理员即可开通对应套餐")
            Text("· 计费透明：每场辩论的成本明细可在意见书页对账")
            Text("· AI 输出为模拟辩论，不构成法律意见")
        }
        .font(.caption2)
        .foregroundStyle(Theme.textSub)
        .padding(12)
        .background(Theme.card)
        .cornerRadius(10)
    }
}

private struct PlanCard: View {
    let plan: PlanInfo
    let isCurrent: Bool
    let highlighted: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(plan.name).font(.headline).foregroundStyle(Theme.textMain)
                if highlighted {
                    Text("最受欢迎")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.accent)
                        .foregroundStyle(Theme.background)
                        .cornerRadius(5)
                }
                if isCurrent {
                    Text("当前")
                        .font(.caption2)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Theme.line)
                        .foregroundStyle(Theme.textMain)
                        .cornerRadius(5)
                }
                Spacer()
                Text(plan.priceCnyMonth == 0 ? "免费" : "¥\(Int(plan.priceCnyMonth))/月")
                    .font(.title3.bold())
                    .foregroundStyle(highlighted ? Theme.accent : Theme.textMain)
            }
            HStack(spacing: 10) {
                Label(plan.casesPerMonth < 0 ? "场次不限" : "每月 \(plan.casesPerMonth) 场",
                      systemImage: "calendar")
                Label("单场 ≤ \(plan.maxRounds) 轮", systemImage: "arrow.triangle.branch")
            }
            .font(.caption)
            .foregroundStyle(Theme.textSub)
            Text(plan.notes)
                .font(.caption2)
                .foregroundStyle(Theme.textSub)
        }
        .padding(14)
        .background(highlighted ? Theme.accent.opacity(0.08) : Theme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14)
            .stroke(highlighted ? Theme.accent : Theme.line,
                    lineWidth: highlighted ? 2 : 1))
    }
}
