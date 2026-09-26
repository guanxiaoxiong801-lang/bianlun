# DebateHub iOS —— SwiftUI 原生版

> 原生 iOS 应用（SwiftUI + async/await，零第三方依赖）。
> 功能对齐 RN 版：场景/发起/辩论直播（像素法庭）/意见书/历史/模型切换/账号/会员/管理端。

## 工程结构

```
debatehub-ios/
├── project.yml                # XcodeGen 工程描述（生成 DebateHub.xcodeproj）
├── codemagic.yaml             # Codemagic 云构建（无 Mac 出包）
├── App/
│   ├── DebateHubApp.swift     # @main
│   ├── RootView.swift         # 底部 Tab：场景/发起/历史/我的
│   ├── Theme.swift            # 主题色（暗色法庭风）
│   ├── Models.swift           # Codable 模型（snake_case 自动转换）
│   ├── APIClient.swift        # async/await 客户端（Bearer/管理令牌）
│   └── Views/
│       ├── ScenesView.swift   # 首页：额度卡 + 场景网格
│       ├── CreateCaseView.swift
│       ├── DebateView.swift   # 轮询推进 + 插话 + 证据
│       ├── PixelCourtView.swift # 像素法庭（Canvas 像素绘制 + 打字机 + HP + 异议）
│       ├── VerdictView.swift  # 结构化意见书
│       ├── HistoryView.swift
│       ├── ProfileView.swift  # 我的：账号/会员入口/管理入口/后端设置
│       ├── PaywallView.swift  # 会员套餐（商业化）
│       ├── LoginView.swift    # 登录/注册
│       └── AdminView.swift    # 管理员：模型启停 + 用量看板
└── Resources/Assets.xcassets  # AppIcon(1024) / AccentColor
```

## 如何出包装机（两条路）

### 路线 A：Codemagic 云构建（推荐，无需 Mac）

1. 在 GitHub 创建**私有仓库**，把本目录推上去（也可以推整个仓库）。
2. 打开 [codemagic.io](https://codemagic.io) → 用 GitHub 登录 → Add application → 选仓库 → 选择 **codemagic.yaml** 工作流。
3. Team settings → **Code signing** → 添加 **App Store Connect API Key**（Issuer ID + Key ID + .p8，与移动端 RN 出包用的同一把即可，但角色需 App Manager 或以上）。
4. 启动 `ios-adhoc` 工作流 → Codemagic 自动：安装 XcodeGen → 生成工程 → 注册设备 → 生成 Ad Hoc 描述文件 → 出 .ipa。
5. 构建完成后，Codemagic 会把**安装链接发到配置的邮箱**，iPhone 打开即装（设备 UDID 需先注册：Codemagic 设备注册页，或沿用已注册的设备 `00008150-001C38A10E44401C`）。

### 路线 B：本地 Mac

```bash
brew install xcodegen
cd debatehub-ios && xcodegen generate
open DebateHub.xcodeproj      # 选 Team → Cmd+R 真机运行
```

## 与后端的契约

默认连云端部署地址（构建前可在 `App/APIClient.swift` 修改默认值，或 App 内「我的 → 后端服务器」随时改）。
账号/配额/管理端与 Web、RN 三端共用同一后端契约（P7 用户系统）。

## 迭代注意

- 工程用 XcodeGen 描述：**改完源码/资源后需重新 `xcodegen generate`**（新增文件必须重新生成）。
- 无法在本机（Windows）编译验证 Swift——提交前建议在 Codemagic 上先跑一次 Debug 构建确认。
- RN 版（debatehub-mobile/）保留用于 Android 出包；两端功能对齐。
