import SwiftUI

/// 全局主题（暗色法庭风：深蓝底 + 青色强调，与 Web/移动端一致）。
enum Theme {
    static let background = Color(red: 0.05, green: 0.08, blue: 0.15)      // #0d1526
    static let card = Color(red: 0.06, green: 0.10, blue: 0.18)            // #0f1a2e
    static let line = Color(red: 0.18, green: 0.24, blue: 0.33)            // #2f3d55
    static let accent = Color(red: 0.0, green: 0.83, blue: 0.67)           // #00d4aa
    static let textMain = Color.white
    static let textSub = Color(red: 0.54, green: 0.63, blue: 0.72)         // #8aa0b8
    static let danger = Color(red: 0.97, green: 0.44, blue: 0.44)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.4)

    static func speakerName(_ raw: String) -> String {
        switch raw {
        case "plaintiff": return "正方"
        case "defendant": return "反方"
        case "judge": return "裁判长"
        case "clerk": return "书记员"
        case "assessor": return "人民陪审员"
        case "observer": return "观战者"
        default: return raw
        }
    }
}


extension Notification.Name {
    static let openPaywall = Notification.Name("openPaywall")
}
