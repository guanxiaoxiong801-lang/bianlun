import Foundation

/// 与后端契约对应的 Codable 模型（snake_case 自动转换）。
/// 说明：解码统一使用 .convertFromSnakeCase（见 APIClient）。

struct HealthInfo: Codable {
    var status: String
    var mockMode: Bool
    var availableVendors: [String]
}

struct ScenarioInfo: Codable, Identifiable, Hashable {
    var scenarioId: String
    var name: String
    var archetype: String
    var plaintiffName: String
    var defendantName: String
    var judgePanelSize: Int
    var useEvidenceStage: Bool
    var kbEnabled: Bool
    var verdictStyle: String
    var description: String

    var id: String { scenarioId }
}

struct ModelInfo: Codable, Identifiable {
    var preset: String
    var kind: String
    var vendor: String
    var modelName: String
    var enabled: Bool
    var available: Bool
    var promptPer1kUsd: Double
    var completionPer1kUsd: Double
    var description: String

    var id: String { preset }
}

struct ModelsResponse: Codable {
    var models: [ModelInfo]
    var mockMode: Bool?
}

struct DebateMessage: Codable, Identifiable {
    var speaker: String
    var stage: String
    var content: String
    var round: Int
    var model: String?
    var kbRefs: [String]?

    var id: String { "\(speaker)-\(stage)-\(round)-\(content.hashValue)" }
}

struct ScoreRow: Codable {
    var speaker: String
    var clarity: Double
    var evidence: Double
    var logic: Double
    var rebuttal: Double
    var total: Double
}

struct EvidenceItem: Codable, Identifiable {
    var evidenceId: String
    var name: String
    var side: String
    var type: String
    var description: String
    var content: String
    var parseStatus: String

    var id: String { evidenceId }
}

struct CaseDetail: Codable, Identifiable {
    var caseId: String
    var title: String
    var description: String
    var scenario: String
    var plaintiffSide: String?
    var defendantSide: String?
    var maxRounds: Int
    var status: String
    var currentStage: String
    var currentSpeaker: String
    var stepIndex: Int
    var roundNumber: Int
    var messages: [DebateMessage]
    var scores: [ScoreRow]
    var verdict: VerdictDoc?
    var summary: VerdictDoc?
    var lastOutput: String
    var mockUsed: Bool
    var degradedEvents: [String]
    var researchUsed: Bool?
    var ownerUsername: String?

    var id: String { caseId }
}

struct AdvancePayload: Codable {
    var caseId: String
    var status: String
    var currentStage: String
    var currentSpeaker: String
    var stepIndex: Int
    var totalSteps: Int
    var lastOutput: String
    var judgeNote: String
    var verdict: VerdictDoc?
    var summary: VerdictDoc?
    var mockUsed: Bool
    var degradedEvents: [String]
    var kbUsed: Bool
    var researchUsed: Bool
}

struct EvidenceAddResponse: Codable {
    var evidenceId: String
    var parseStatus: String
}

struct ScoreResponse: Codable {
    var caseId: String
    var count: Int
    var source: String
    var scores: [ScoreRow]
}

struct VerdictDoc: Codable {
    var winner: String?
    var winningProbability: Double?
    var winningProbabilityNote: String?
    var title: String?
    var dimensionScores: [String: DimensionScore]?
    var disputeFocus: [String]?
    var evidenceAdoption: [EvidenceAdoption]?
    var legalProvisions: [String]?
    var actionAdvice: [String]?
    var opinionSummary: String?
    var disclaimer: String?
    var generatedBy: String?
}

struct DimensionScore: Codable {
    var clarity: Double
    var evidence: Double
    var logic: Double
    var rebuttal: Double
    var total: Double
}

struct EvidenceAdoption: Codable {
    var evidence: String
    var adopted: String?
    var reason: String?
}

// ---- 账号与商业化（P7） ----

struct QuotaUsage: Codable {
    var plan: String
    var planName: String
    var casesThisMonth: Int
    var casesLimit: Int
    var maxRounds: Int
    var totalCases: Int
}

struct CurrentUser: Codable {
    var userId: String
    var username: String
    var email: String?
    var role: String
    var plan: String
    var usage: QuotaUsage
}

struct AuthResponse: Codable {
    var user: CurrentUser
    var token: String
}

struct PlanInfo: Codable, Identifiable {
    var plan: String
    var name: String
    var priceCnyMonth: Double
    var casesPerMonth: Int
    var maxRounds: Int
    var notes: String

    var id: String { plan }
}

struct PlansResponse: Codable {
    var plans: [PlanInfo]
}

// ---- 管理端 ----

struct AdminRegistryEntry: Codable, Identifiable {
    var preset: String
    var kind: String
    var vendor: String
    var modelName: String
    var enabled: Bool
    var available: Bool
    var apiKeyMasked: String?

    var id: String { preset }
}

struct AdminRegistryResponse: Codable {
    var models: [AdminRegistryEntry]
    var count: Int
}

struct UsageModelRow: Codable {
    var calls: Int
    var promptTokens: Int
    var completionTokens: Int
    var costUsd: Double

    enum CodingKeys: String, CodingKey {
        case calls
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case costUsd = "cost_usd"
    }
}

struct AdminUsage: Codable {
    var overview: UsageOverview
    var byModel: [String: UsageModelRow]

    enum CodingKeys: String, CodingKey {
        case overview
        case byModel = "by_model"
    }
}

struct UsageOverview: Codable {
    var calls: Int
    var mockCalls: Int
    var promptTokens: Int
    var completionTokens: Int
    var totalCostUsd: Double

    enum CodingKeys: String, CodingKey {
        case calls
        case mockCalls = "mock_calls"
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalCostUsd = "total_cost_usd"
    }
}
