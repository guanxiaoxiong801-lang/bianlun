import SwiftUI

/// 登录 / 注册（回调返回最新用户）。
struct LoginView: View {
    var onAuthenticated: (CurrentUser) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .login
    @State private var username = ""
    @State private var password = ""
    @State private var email = ""
    @State private var busy = false
    @State private var error = ""

    private let api = APIClient.shared

    enum Mode { case login, register }

    var body: some View {
        NavigationStack {
            Form {
                Picker("", selection: $mode) {
                    Text("登录").tag(Mode.login)
                    Text("注册").tag(Mode.register)
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)

                Section(mode == .register ? "创建账号（免费版，每月 3 场）" : "账号") {
                    TextField("用户名（3-32 位）", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField(mode == .register ? "密码（至少 8 位）" : "密码", text: $password)
                    if mode == .register {
                        TextField("邮箱（选填）", text: $email)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                    }
                }

                Section {
                    Button {
                        Task { await submit() }
                    } label: {
                        HStack {
                            Spacer()
                            if busy { ProgressView().tint(Theme.background) }
                            else { Text(mode == .login ? "登录" : "注册并登录").bold() }
                            Spacer()
                        }
                    }
                    .listRowBackground(Theme.accent)
                    .disabled(busy || username.isEmpty || password.isEmpty)
                }

                if !error.isEmpty {
                    Section { Text(error).foregroundStyle(Theme.danger).font(.footnote) }
                }

                Section {
                    Text("本平台为 AI 模拟辩论，输出不构成法律意见。")
                        .font(.caption2)
                        .foregroundStyle(Theme.textSub)
                }
            }
            .navigationTitle("账号")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func submit() async {
        error = ""
        busy = true
        defer { busy = false }
        do {
            let res: AuthResponse
            switch mode {
            case .login: res = try await api.login(username: username, password: password)
            case .register: res = try await api.register(username: username,
                                                         password: password, email: email)
            }
            api.setAuth(token: res.token, user: res.user)
            onAuthenticated(res.user)
            dismiss()
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? "操作失败"
        }
    }
}
