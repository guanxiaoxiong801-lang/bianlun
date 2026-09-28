import Foundation

/// 辩题库：读取打包进 App 的 debate_topics_v1.json，按场景随机抽题。
/// 六个场景 key 与 ScenarioInfo.scenarioId 一一对应；未知场景回落 legal。
enum TopicStore {

    private static var cache: [String: [String]]?

    /// 从指定场景随机抽 3 条辩题；文件缺失或解析失败时抛错，不静默返回空。
    static func randomThree(scenario: String) throws -> [String] {
        let topics = try loadTopics()[key(for: scenario)] ?? []
        return Array(topics.shuffled().prefix(3))
    }

    // MARK: - 加载

    private static func key(for scenario: String) -> String {
        ["legal", "consumer", "business", "workplace", "education", "public"].contains(scenario)
            ? scenario : "legal"
    }

    private static func loadTopics() throws -> [String: [String]] {
        if let cache { return cache }
        guard let url = Bundle.main.url(forResource: "debate_topics_v1", withExtension: "json") else {
            throw TopicError.resourceMissing
        }
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw TopicError.resourceUnreadable(url.lastPathComponent, error)
        }
        do {
            let topics = try JSONDecoder().decode([String: [String]].self, from: data)
            cache = topics
            return topics
        } catch {
            throw TopicError.decoding(url.lastPathComponent, error)
        }
    }

    // MARK: - 错误

    enum TopicError: LocalizedError {
        case resourceMissing
        case resourceUnreadable(String, Error)
        case decoding(String, Error)

        var errorDescription: String? {
            switch self {
            case .resourceMissing:
                return "辩题库文件缺失：Bundle 中未找到 debate_topics_v1.json，请确认已加入 target 资源"
            case .resourceUnreadable(let name, let error):
                return "辩题库文件不可读：\(name)（\(error.localizedDescription)）"
            case .decoding(let name, let error):
                return "辩题库解析失败：\(name)（\(error.localizedDescription)）"
            }
        }
    }
}
