import SwiftUI

/// 裁判意见书（结构化八节 + 幻觉校验 + 免责声明）。
struct VerdictView: View {
    let caseId: String

    @State private var verdict: VerdictDoc?
    @State private var mockUsed = false
    @State private var error = ""
    @State private var loading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if loading { ProgressView().frame(maxWidth: .infinity) }
                if !error.isEmpty { Text(error).foregroundStyle(Theme.danger) }
                if let v = verdict { sections(v) }
            }
            .padding(16)
        }
        .background(Theme.background)
        .navigationTitle("裁判意见书")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private func load() async {
        do {
            verdict = try await APIClient.shared.verdict(caseId)
            mockUsed = false
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "加载失败"
        }
        loading = false
    }

    @ViewBuilder
    private func sections(_ v: VerdictDoc) -> some View {
        if mockUsed {
            Label("本场包含 Mock/降级数据", systemImage: "exclamationmark.triangle")
                .font(.caption).foregroundStyle(Theme.gold)
        }
        if let prob = v.winningProbability {
            VStack(spacing: 6) {
                Text("原告胜诉概率").font(.caption).foregroundStyle(Theme.textSub)
                Text("\(Int(prob * 100))%")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.accent)
                if let note = v.winningProbabilityNote {
                    Text(note).font(.caption).foregroundStyle(Theme.textSub)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(14)
            .background(Theme.card)
            .cornerRadius(14)
        }
        if let scores = v.dimensionScores {
            VStack(alignment: .leading, spacing: 8) {
                Text("双方评分（裁判团）").font(.headline).foregroundStyle(Theme.textMain)
                ForEach(["plaintiff", "defendant"], id: \.self) { party in
                    if let d = scores[party] {
                        HStack {
                            Text(Theme.speakerName(party)).font(.subheadline)
                            Spacer()
                            Text("清晰\(Int(d.clarity)) 证据\(Int(d.evidence)) 逻辑\(Int(d.logic)) 反驳\(Int(d.rebuttal))")
                                .font(.caption)
                            Text("\(Int(d.total))").font(.headline).foregroundStyle(Theme.accent)
                        }
                        .foregroundStyle(Theme.textMain)
                    }
                }
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(12)
        }
        if let focus = v.disputeFocus, !focus.isEmpty {
            section("争议焦点") {
                ForEach(focus, id: \.self) { bullet(Text($0)) }
            }
        }
        if let adoption = v.evidenceAdoption, !adoption.isEmpty {
            section("证据采信") {
                ForEach(Array(adoption.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(item.evidence).font(.subheadline)
                            if let adopted = item.adopted {
                                Text(String(describing: adopted))
                                    .font(.caption2)
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(Theme.line.opacity(0.5))
                                    .cornerRadius(5)
                            }
                        }
                        if let reason = item.reason {
                            Text(reason).font(.caption).foregroundStyle(Theme.textSub)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        if let provisions = v.legalProvisions, !provisions.isEmpty {
            section("引用法条") {
                ForEach(provisions, id: \.self) { bullet(Text($0).font(.callout)) }
            }
        }
        if let advice = v.actionAdvice, !advice.isEmpty {
            section("行动建议") {
                ForEach(advice, id: \.self) { bullet(Text($0)) }
            }
        }
        if let summary = v.opinionSummary {
            section("综合评议") { Text(summary).lineSpacing(4) }
        }
        if let disclaimer = v.disclaimer {
            Text("⚠️ " + disclaimer)
                .font(.caption2)
                .foregroundStyle(Theme.textSub)
                .padding(10)
                .background(Theme.card)
                .cornerRadius(8)
        }
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.accent)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .cornerRadius(12)
    }

    private func bullet(_ text: some View) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("·").foregroundStyle(Theme.accent)
            text.foregroundStyle(Theme.textMain)
        }
    }
}
