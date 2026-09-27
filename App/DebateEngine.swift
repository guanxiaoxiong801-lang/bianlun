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

    /// 逐步推进直到 completed；断网时等待恢复自动续跑。
    func runToCompletion() async {
        guard !running else { return }
        running = true
        defer { running = false }

        var backoff: UInt64 = 1_000_000_000   // 1s 起
        while status != "completed" && status != "error" {
            do {
                let adv = try await api.advance(caseId)
                backoff = 1_000_000_000
                apply(adv)
                if adv.status == "completed" { break }
                try? await Task.sleep(for: stepPace)
            } catch {
                // 指数退避；离线时等网络恢复再继续，最多退到 32s
                connectionLost = true
                try? await Task.sleep(for: .nanoseconds(backoff))
                backoff = min(backoff * 2, 32_000_000_000)
                if monitor.isOnline { connectionLost = false }
            }
        }
        await reload()
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
