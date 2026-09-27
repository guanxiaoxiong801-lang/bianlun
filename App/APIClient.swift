import Foundation

/// 后端 API 客户端（async/await；统一 Bearer/管理令牌注入与错误呈现）。
final class APIClient {
    static let shared = APIClient()
    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 300   // 真实模型单步 20~60s，放宽
        cfg.timeoutIntervalForResource = 1800 // SSE/长流程
        return URLSession(configuration: cfg)
    }()

    /// 后端地址：编译期写死（App 内不暴露、不可改、用户零操作）。
    /// 更换后端 = 改这里的常量后重新构建。
    static let defaultBaseURL = "https://arrange-calls-midwest-inspection.trycloudflare.com"

    private(set) var baseURL: String = APIClient.defaultBaseURL

    var authToken: String? { UserDefaults.standard.string(forKey: "dh.authToken") }
    var adminToken: String? { UserDefaults.standard.string(forKey: "dh.adminToken") }

    func setAuth(token: String?, user: CurrentUser?) {
        if let token { UserDefaults.standard.set(token, forKey: "dh.authToken") }
        else { UserDefaults.standard.removeObject(forKey: "dh.authToken") }
        if let user, let data = try? JSONEncoder().encode(user) {
            UserDefaults.standard.set(data, forKey: "dh.user")
        }
    }

    func savedUser() -> CurrentUser? {
        guard let data = UserDefaults.standard.data(forKey: "dh.user") else { return nil }
        return try? JSONDecoder().decode(CurrentUser.self, from: data)
    }

    enum APIError: LocalizedError {
        case network(String)
        case http(Int, String)

        var errorDescription: String? {
            switch self {
            case .network(let base): return "无法连接后端（\(base)），请在「设置」检查地址"
            case .http(let code, let detail): return "HTTP \(code)：\(detail)"
            }
        }
    }

    private func request<T: Decodable>(_ type: T.Type, path: String,
                                       method: String = "GET", body: [String: Any]? = nil,
                                       auth: Bool = true, admin: Bool = false) async throws -> T {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.network(baseURL)
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if auth, let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if admin, let token = adminToken {
            req.setValue(token, forHTTPHeaderField: "X-Admin-Token")
        }
        if let body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.network(baseURL) }
        guard (200..<300).contains(http.statusCode) else {
            let detail = (try? JSONDecoder().decode(DetailBody.self, from: data))?.detail ?? "HTTP \(http.statusCode)"
            throw APIError.http(http.statusCode, detail)
        }
        let dec = JSONDecoder()
        dec.keyDecodingStrategy = .convertFromSnakeCase
        return try dec.decode(type, from: data)
    }

    private struct DetailBody: Codable { var detail: String }

    // ---- 公开 ----
    func health() async throws -> HealthInfo {
        try await request(HealthInfo.self, path: "/api/health", auth: false)
    }
    func scenarios() async throws -> [ScenarioInfo] {
        try await request(ScenarioListResponse.self, path: "/api/scenarios", auth: false).scenarios
    }
    func models() async throws -> [ModelInfo] {
        try await request(ModelsResponse.self, path: "/api/models", auth: false).models
    }
    func plans() async throws -> [PlanInfo] {
        try await request(PlansResponse.self, path: "/api/billing/plans", auth: false).plans
    }

    // ---- 账号 ----
    func register(username: String, password: String, email: String?) async throws -> AuthResponse {
        var body: [String: Any] = ["username": username, "password": password]
        if let email, !email.isEmpty { body["email"] = email }
        return try await request(AuthResponse.self, path: "/api/auth/register",
                                 method: "POST", body: body, auth: false)
    }
    func login(username: String, password: String) async throws -> AuthResponse {
        try await request(AuthResponse.self, path: "/api/auth/login",
                          method: "POST", body: ["username": username, "password": password], auth: false)
    }
    func me() async throws -> CurrentUser {
        try await request(MeResponse.self, path: "/api/auth/me").user
    }

    private struct MeResponse: Codable { var user: CurrentUser }
    private struct ScenarioListResponse: Codable { var scenarios: [ScenarioInfo] }

    // ---- 案件 ----
    func createCase(title: String, description: String, scenario: String,
                    plaintiffSide: String?, defendantSide: String?,
                    maxRounds: Int?, modelOverride: [String: Any]?) async throws -> String {
        var body: [String: Any] = [
            "title": title, "description": description, "scenario": scenario,
            "plaintiff_side": plaintiffSide ?? "",
        ]
        if let defendantSide { body["defendant_side"] = defendantSide }
        if let maxRounds { body["max_rounds"] = maxRounds }
        if let modelOverride { body["model_override"] = modelOverride }
        struct Created: Codable { var caseId: String }
        return try await request(Created.self, path: "/api/cases", method: "POST", body: body).caseId
    }

    func getCase(_ caseId: String) async throws -> CaseDetail {
        try await request(CaseDetail.self, path: "/api/cases/\(caseId)")
    }
    func listCases() async throws -> [CaseDetail] {
        try await request([CaseDetail].self, path: "/api/cases")
    }
    func startCase(_ caseId: String) async throws {
        struct Started: Codable {}
        _ = try? await request(Started.self, path: "/api/cases/\(caseId)/start", method: "POST")
        // start 的响应体各字段非必需；错误仍会抛出
    }
    func advance(_ caseId: String) async throws -> AdvancePayload {
        try await request(AdvancePayload.self, path: "/api/cases/\(caseId)/advance", method: "POST")
    }
    func interrupt(_ caseId: String, speaker: String, content: String) async throws {
        struct R: Codable {}
        _ = try await request(R.self, path: "/api/cases/\(caseId)/interrupt",
                              method: "POST",
                              body: ["speaker": speaker, "content": content])
    }
    func scores(_ caseId: String) async throws -> ScoreResponse {
        try await request(ScoreResponse.self, path: "/api/cases/\(caseId)/scores")
    }
    func addEvidenceText(_ caseId: String, name: String, side: String, content: String) async throws {
        struct R: Codable { var evidenceId: String; var parseStatus: String }
        _ = try await request(R.self, path: "/api/cases/\(caseId)/evidence",
                              method: "POST",
                              body: ["name": name, "source": side, "type": "text", "content": content])
    }
    func verdict(_ caseId: String) async throws -> VerdictDoc {
        struct R: Codable { var verdict: VerdictDoc }
        return try await request(R.self, path: "/api/cases/\(caseId)/verdict").verdict
    }

    // ---- 管理端 ----
    func adminRegistry() async throws -> AdminRegistryResponse {
        try await request(AdminRegistryResponse.self, path: "/api/admin/registry", admin: true)
    }
    func adminToggleModel(preset: String, enabled: Bool) async throws {
        struct R: Codable {}
        _ = try await request(R.self, path: "/api/admin/models/\(preset)", method: "PATCH",
                              body: ["enabled": enabled], admin: true)
    }
    func adminUsage() async throws -> AdminUsage {
        try await request(AdminUsage.self, path: "/api/admin/usage", admin: true)
    }
}
