import SwiftUI
import UIKit

/// 键盘收起辅助：不使用整页 Tap 手势（会干扰 Picker/按钮），改用
/// ① ScrollView 拖动自动收起（scrollDismissesKeyboard）
/// ② 键盘工具条「完成」按钮
struct KeyboardToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil)
                }
                .foregroundStyle(Theme.accent)
            }
        }
    }
}

extension View {
    func keyboardDoneButton() -> some View {
        modifier(KeyboardToolbar())
    }
}
