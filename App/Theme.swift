import SwiftUI

/// 全局主题（暗色法庭风：深蓝底 + 青色强调，与 Web/移动端一致）。
enum Theme {
    // V21「月下辩城」皮肤：深紫夜底 + 鎏金强调（2026-09-29 全端统一，与 Web /town 一致）
    static let background = Color(red: 0.08, green: 0.05, blue: 0.13)      // #140d22 深紫夜
    static let card = Color(red: 0.11, green: 0.08, blue: 0.19)            // #1d1530 紫檀卡面
    static let line = Color(red: 0.29, green: 0.24, blue: 0.41)            // #4a3c68 暮紫描线
    static let accent = Color(red: 0.83, green: 0.69, blue: 0.35)          // #d4af5a 鎏金
    static let textMain = Color.white
    static let textSub = Color(red: 0.71, green: 0.66, blue: 0.80)         // #b5a8cc 月雾紫
    static let danger = Color(red: 0.88, green: 0.32, blue: 0.32)
    static let gold = Color(red: 1.0, green: 0.91, blue: 0.66)             // #ffe9a8 月光金

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
