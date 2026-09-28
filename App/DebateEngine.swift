import Foundation
import SwiftUI

/// 原生辩论引擎：App 内置的辩论状态机与推进编排（不依赖任何 Web 容器）。
///
/// 职责：
/// - 持有单场辩论的本地运行时状态（阶段/步数/发言流/评分/HP）
/// - 以原生命中周期驱动 advance（含指数退避与断网自动续跑）
/// - 把后端结构化输出转成本地展示模型（供像素法庭/对白流/裁判意见书使用）
@MainActor
final class DebateEngine: ObservableObject {

    // MARK: - 本地展示状态

    @Published var messages: [DebateMessage] = []
    @Published var status: String = "pending"
    @Published var stepIndex: Int = 0
    @Published var stepTotal: Int = 0
    @Published var speaker: String = ""
    @Published var lastOutput: String = ""
    @Published var hpPlaintiff: Double?
    @Published var hpDefendant: Double?
    @Published var verdict: VerdictDoc?
    @Published var running = false
    @Published var connectionLost = false
    @Published var liveText = ""          // SSE 打字机当前片段
    @Published var liveSpeaker = ""       // 当前发言方
    @Published var useSSE = true          // SSE 不可用时自动降级

    /// 每步之间的人为停顿（直播观感；真实模型单步 20~60s，另计）
    var stepPace: Duration = .milliseconds(400)

    private let api = APIClient.shared
    private let monitor = NetworkMonitor.shared
    private var caseId = ""

    // MARK: - 生命周期

    func bind(caseId: String) async {
        self.caseId = caseId
        await reload()
    }

    /// 拉取服务端权威状态并刷新本地展示模型。
    func reload() async {
        guard let detail = try? await api.getCase(caseId) else {
            connectionLost = !monitor.isOnline ? false : connectionLost
            return
        }
        status = detail.status
        stepIndex = detail.stepIndex
        messages = detail.messages
        rebuildHP()
        if let v = detail.verdict { verdict = v }
    }

    // MARK: - 推进循环（原生驱动）

    /// 逐步推进直到 completed。
    /// judgment 步（三裁判合议）耗时 60~180s，公网网关可能中途切断长请求：
    /// 因此 advance 失败/超时后**不盲目重发**，转入 getCase 轮询模式——
    /// 服务端状态机会继续执行，轮询直到 step_index 前进或 completed，天然幂等。
    func runToCompletion() async {
        guard !running else { return }
        running = true
        defer { running = false }

        if useSSE {
            await runViaSSE()
            if status == "completed" || status == "error" { running = false; return }
            useSSE = false // SSE 失败降级
        }

        var backoff: UInt64 = 2_000_000_000   // 2s 起
        while status != "completed" && status != "error" {
            let beforeStep = stepIndex
            do {
                let adv = try await api.advance(caseId)
                backoff = 2_000_000_000
                apply(adv)
                if adv.status == "completed" { break }
                try? await Task.sleep(for: stepPace)
            } catch {
                // 长请求被切断或网络抖动 → 轮询权威状态直到推进完成
                connectionLost = true
                await pollUntilProgress(from: beforeStep)
                connectionLost = false
                backoff = 2_000_000_000
            }
        }
        await reload()
    }

    /// 轮询服务端权威状态：每 5s 一次，直到步数前进或辩论结束（上限 10 分钟）。
    private func pollUntilProgress(from step: Int, timeoutSeconds: Int = 600) async {
        let deadline = Date().addingTimeInterval(TimeInterval(timeoutSeconds))
        while Date() < deadline {
            try? await Task.sleep(for: .seconds(5))
            guard let detail = try? await api.getCase(caseId) else { continue }
            status = detail.status
            messages = detail.messages
            stepIndex = detail.stepIndex
            stepTotal = max(stepTotal, detail.messages.count)
            if let v = detail.verdict { verdict = v }
            if detail.stepIndex > step || detail.status == "completed"
                || detail.status == "error" {
                rebuildHP()
                return
            }
        }
    }

    /// 人民陪审员插话（原生入口，服务端 /interrupt）。
    func interrupt(as speaker: String, content: String) async -> Bool {
        let ok = (try? await api.interrupt(caseId, speaker: speaker, content: content)) != nil
        if ok { await reload() }
        return ok
    }

    // MARK: - 私有

    private func apply(_ adv: AdvancePayload) {
        status = adv.status
        stepIndex = adv.stepIndex
        stepTotal = max(stepTotal, adv.totalSteps)
        speaker = adv.currentSpeaker
        lastOutput = adv.lastOutput
        if let v = adv.verdict { verdict = v }
        if !adv.lastOutput.isEmpty {
            messages.append(DebateMessage(speaker: adv.currentSpeaker,
                                          stage: adv.currentStage,
                                          content: adv.lastOutput,
                                          round: 0,
                                          kbRefs: nil))
        }
        rebuildHP()
    }

    /// HP：按双方最近若干条发言的长度与评分本地推导（纯本地视觉反馈，不回传）。
    private func rebuildHP() {
        func sideHP(_ who: String, fallback: Double) -> Double {
            let mine = messages.filter { $0.speaker == who }
            guard !mine.isEmpty else { return fallback }
            let recent = mine.suffix(3).reduce(0) { $0 + min(120, $1.content.count) }
            return min(100, 45 + Double(recent) / 9)
        }
        hpPlaintiff = sideHP("plaintiff", fallback: 100)
        hpDefendant = sideHP("defendant", fallback: 100)
    }
}

/// 纯原生网络监听（NWPathMonitor），供断网续跑与连接徽标使用。
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()
    @Published private(set) var isOnline = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "debatehub.netmon")

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }
}

// MARK: - SSE 流式直播（打字机效果）

extension DebateEngine {
    /// 连接 /stream2 消费 delta/step/done 事件；断流降级 advance 模式。
    func runViaSSE() async {
        do {
            for try await (event, data) in api.sseEvents(caseId: caseId) {
                let jsonData = Data(data.utf8)
                switch event {
                case "delta":
                    if let obj = try? JSONDecoder().decode(DeltaEvent.self, from: jsonData) {
                        liveText += obj.text
                    }
                case "step":
                    if let obj = try? JSONDecoder().decode(StepEvent.self, from: jsonData) {
                        liveText = ""
                        liveSpeaker = ""
                        status = obj.status
                        stepIndex = obj.stepIndex
                        stepTotal = max(stepTotal, obj.totalSteps)
                        speaker = obj.currentSpeaker
                        if let out = obj.lastOutput, !out.isEmpty,
                           !messages.contains(where: { $0.content == out }) {
                            messages.append(DebateMessage(speaker: obj.currentSpeaker,
                                                          stage: obj.currentStage,
                                                          content: out, round: 0,
                                                          model: obj.model))
                        }
                        rebuildHP()
                    }
                case "done":
                    status = (try? JSONDecoder().decode(DoneEvent.self, from: jsonData))?.status ?? "completed"
                    await reload()
                    return
                case "error":
                    status = "error"
                    return
                default: break
                }
            }
        } catch {
            await reload() // 断流降级
        }
    }
}

struct DeltaEvent: Codable { var text: String }
struct StepEvent: Codable {
    var status: String
    var currentStage: String
    var currentSpeaker: String
    var stepIndex: Int
    var totalSteps: Int
    var lastOutput: String?
    var model: String?
}
struct DoneEvent: Codable { var status: String }

