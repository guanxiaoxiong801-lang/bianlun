import SwiftUI
import UIKit

/// 点击空白处收起键盘（原生手势扩展，全局可用）。
struct HideKeyboardOnTap: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onTapGesture {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil, from: nil, for: nil)
            }
    }
}

extension View {
    func hideKeyboardOnTap() -> some View {
        modifier(HideKeyboardOnTap())
    }
}
