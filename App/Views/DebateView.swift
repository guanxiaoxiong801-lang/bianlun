import SwiftUI

/// 辩论直播：像素法庭置顶 + 对白流 + 人民陪审员插话 + 证据。
/// RN 端为轮询 /advance（真实模型单步 20~60s，属正常）。
struct DebateView: View {
    let caseId: String

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var messages: [DebateMessage] = []
    @State private var status = "pending"
    @State private var stepIndex = 0
    @State private var stepTotal = 0
    @State private var speaker = "clerk"
    @State private var lastOutput = ""
    @State private var running = false
    @State private var objection = false
    @State private var hpP: Double?
    @State private var hpD: Double?
    @State private var verdictReady = false
    @State private var interruptText = ""
    @State private var error = ""
    @StateObject private var engine = DebateEngine()
    @State private var evidence: [EvidenceItem] = []
    @State private var newEvidence = ""

    private let api = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            PixelCourtView(speaker: speaker, text: lastOutput,
                           stepText: stepTotal > 0 ? "\(stepIndex)/\(stepTotal)" : status,
                           hpPlaintiff: hpP, hpDefendant: hpD, objection: objection)
                .frame(height: 240)
                .clipped()
            progressBar
            messageList
            interruptBar
        }
        .background(Theme.background)
        .navigationTitle(title.isEmpty ? "辩论" : title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if status == "completed", verdictReady {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("意见书") { VerdictView(caseId: caseId) }
                }
            }
        }
        .task { await loadAll() }
        .onDisappear { engine.running = false }
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(Theme.card)
                Rectangle().fill(Theme.accent)
                    .frame(width: stepTotal > 0 ? geo.size.width * CGFloat(stepIndex) / CGFloat(stepTotal) : 0)
            }
        }
        .frame(height: 3)
    }

    private var messageList: some View {
        ScrollView {
            VStack(spacing: 10) {
                if status == "pending" && !running {
                    Button { startPolling() } label: {
                        Text("开始辩论")
                            .font(.headline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Theme.accent)
                            .foregroundStyle(Theme.background)
                            .cornerRadius(12)
                    }
                }
                ForEach(messages) { m in
                    MessageRow(message: m)
                }
                if running { ProgressView().tint(Theme.accent).padding(8) }
                if status == "completed" {
                    Text("辩论已结束")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSub)
                }
            }
            .padding(12)
        }
    }

    private var interruptBar: some View {
        HStack(spacing: 8) {
            TextField("以人民陪审员身份插话…", text: $interruptText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
                .font(.subheadline)
            Button {
                Task { await sendInterrupt() }
            } label: {
                Image(systemName: "paperplane.fill")
                    .padding(10)
                    .background(interruptText.isEmpty ? Theme.line : Theme.accent)
                    .foregroundStyle(Theme.background)
                    .cornerRadius(10)
            }
            .disabled(interruptText.isEmpty)
            Menu {
                Button("追加文字证据") { Task { await addEvidence() } }
            } label: {
                Image(systemName: "paperclip")
                    .padding(10)
                    .background(Theme.card)
                    .foregroundStyle(Theme.textSub)
                    .cornerRadius(10)
            }
        }
        .padding(10)
        .background(Theme.card)
    }

    // MARK: - 数据流

    private func loadAll() async {
        do {
            let c = try await api.getCase(caseId)
            title = c.title
            messages = c.messages
            status = c.status
            stepIndex = c.stepIndex
            speaker = c.currentSpeaker.isEmpty ? "clerk" : c.currentSpeaker
            lastOutput = c.lastOutput
            verdictReady = c.verdict != nil
            if c.status == "completed" { await refreshHP() }
            if status == "running" { startPolling() }
            // 创建后进入本页即自动开始：无需用户再点“开始辩论”
            if status == "pending" { startPolling() }
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "加载失败"
        }
    }

    private func startPolling() {
        guard !running else { return }
        running = true
        error = ""
        Task {
            do {
                if status == "pending" { try await api.startCase(caseId) }
                await engine.bind(caseId: caseId)
                await engine.runToCompletion()
                // 同步引擎状态回本地展示变量（保持 UI 兼容）
                status = engine.status
                messages = engine.messages
                stepIndex = engine.stepIndex
                stepTotal = engine.stepTotal
                verdictReady = engine.verdict != nil
                if engine.verdict != nil { objection = true }
                running = false
            } catch is CancellationError {
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? "直播中断（可点击继续）"
                running = false
                status = "error"
            }
        }
    }

    private func refreshHP() async {
        guard let r = try? await api.scores(caseId) else { return }
        for row in r.scores {
            if row.speaker == "plaintiff" { hpP = row.total }
            if row.speaker == "defendant" { hpD = row.total }
        }
    }

    private func sendInterrupt() async {
        let text = interruptText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        do {
            try await api.interrupt(caseId, speaker: "assessor", content: text)
            messages.append(DebateMessage(speaker: "assessor", stage: "interrupt",
                                          content: "【人民陪审员】\(text)", round: 0))
            interruptText = ""
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "插话失败"
        }
    }

    private func addEvidence() async {
        let text = interruptText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        do {
            _ = try await api.addEvidenceText(caseId, name: "补充说明",
                                              side: "neutral", content: text)
            interruptText = ""
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "证据提交失败"
        }
    }
}

struct MessageRow: View {
    let message: DebateMessage

    var body: some View {
        let isHuman = ["assessor", "observer", "human", "system"].contains(message.speaker)
        HStack {
            if isHuman { Spacer(minLength: 40) }
            VStack(alignment: isHuman ? .trailing : .leading, spacing: 3) {
                Text(Theme.speakerName(message.speaker) + " · " + message.stage)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.textSub)
                Text(message.content)
                    .font(.subheadline)
                    .foregroundStyle(isHuman ? Theme.textMain : Theme.textMain)
                    .lineSpacing(3)
            }
            .padding(10)
            .background(isHuman ? Theme.accent.opacity(0.12) : Theme.card)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
            if !isHuman { Spacer(minLength: 40) }
        }
    }
}
