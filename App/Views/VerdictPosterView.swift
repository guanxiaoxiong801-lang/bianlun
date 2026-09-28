import SwiftUI
import UIKit

/// 判决海报：深色法庭风 9:16（390×844，ImageRenderer scale=3 输出）。
/// 数据来源：VerdictDoc（winningProbability / dimensionScores / opinionSummary / legalProvisions）。
struct VerdictPosterView: View {
    let title: String
    let verdict: VerdictDoc

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?
    @State private var saveMessage: String?
    @State private var saver = PosterPhotoSaver()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image = rendered {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 520)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.line, lineWidth: 1))
                } else {
                    ZStack {
                        Theme.card
                        ProgressView("正在渲染海报…")
                            .foregroundStyle(Theme.textSub)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 520)
                    .cornerRadius(16)
                }

                if let message = saveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(saveError ? Theme.danger : Theme.accent)
                }

                HStack(spacing: 12) {
                    Button {
                        saveMessage = nil
                        saver.onFinish = { self.saveMessage = $0 }
                        if let image = rendered { saver.save(image) }
                    } label: {
                        Label("保存到相册", systemImage: "square.and.arrow.down")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(Theme.accent)
                            .foregroundStyle(Theme.background)
                            .cornerRadius(12)
                    }
                    .disabled(rendered == nil)

                    if let image = rendered {
                        ShareLink(item: Image(uiImage: image),
                                  preview: SharePreview("辩坛 AI 判决海报", image: Image(uiImage: image))) {
                            Label("分享", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Theme.accent.opacity(0.14))
                                .foregroundStyle(Theme.accent)
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(16)
            .background(Theme.background)
            .navigationTitle("判决海报")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
            .task {
                let renderer = ImageRenderer(content: VerdictPosterCanvas(title: title, verdict: verdict))
                renderer.scale = 3
                renderer.isOpaque = true
                rendered = renderer.uiImage
            }
        }
    }

    private var saveError: Bool { saveMessage != nil && saveMessage != PosterPhotoSaver.successText }
}

/// 相册写入回调桥（UIImageWriteToSavedPhotosAlbum 的 delegate 风格回调 → 结果字符串）。
final class PosterPhotoSaver: NSObject {
    static let successText = "已保存到相册"

    var onFinish: ((String) -> Void)?

    func save(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self,
                                       #selector(image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        DispatchQueue.main.async {
            self.onFinish?(error?.localizedDescription ?? Self.successText)
        }
    }
}

// MARK: - 画布（固定 390×844）

/// 海报画布本体：仅负责视觉排版，无交互。
struct VerdictPosterCanvas: View {
    let title: String
    let verdict: VerdictDoc

    /// 深色法庭风配色（海报专用，与规范一致）。
    private let bg = Color(red: 0x14 / 255.0, green: 0x0D / 255.0, blue: 0x22 / 255.0)      // #140D22 V21 月下紫夜
    private let card = Color(red: 0x14 / 255.0, green: 0x1C / 255.0, blue: 0x2E / 255.0)    // #141C2E
    private let gold = Color(red: 0xD4 / 255.0, green: 0xAF / 255.0, blue: 0x37 / 255.0)    // #D4AF37
    private let blue = Color(red: 0x4A / 255.0, green: 0x90 / 255.0, blue: 0xD9 / 255.0)    // #4A90D9
    private let main = Color(red: 0xF5 / 255.0, green: 0xF7 / 255.0, blue: 0xFA / 255.0)    // #F5F7FA
    private let sub = Color(red: 0x8A / 255.0, green: 0x93 / 255.0, blue: 0xA6 / 255.0)     // #8A93A6

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: Date())
    }

    private var probabilityText: String {
        guard let p = verdict.winningProbability else { return "--" }
        return "\(Int((p * 100).rounded()))%"
    }

    private var summaryText: String {
        guard let s = verdict.opinionSummary, !s.isEmpty else { return "本场未生成核心结论" }
        return s
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar                    // ① 顶部条 + 日期
            posterTitle               // ② 案件标题（≤2 行）
            probabilityBlock          // ③ 胜诉概率大数字
            scoreCard                 // ④ 双方评分对比条
            conclusionCard            // ⑤ 核心结论（≤3 行）
            Spacer(minLength: 12)
            footer                    // ⑥ 引用法条 N 条 + 平台水印
        }
        .padding(.horizontal, 26)
        .padding(.top, 26)
        .padding(.bottom, 22)
        .frame(width: 390, height: 844, alignment: .top)
        .background(bg)
        .foregroundStyle(main)
    }

    // ①
    private var topBar: some View {
        HStack {
            Text("AI 辩论 · 判决书")
                .font(.system(size: 13, weight: .bold))
                .tracking(3)
                .foregroundStyle(gold)
            Spacer()
            Text(dateText)
                .font(.system(size: 12))
                .foregroundStyle(sub)
        }
        .padding(.bottom, 22)
    }

    // ②
    private var posterTitle: some View {
        Text(title.isEmpty ? "未命名案件" : title)
            .font(.system(size: 22, weight: .bold))
            .foregroundStyle(main)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
    }

    // ③
    private var probabilityBlock: some View {
        VStack(spacing: 4) {
            Text(probabilityText)
                .font(.system(size: 90, weight: .bold, design: .rounded))
                .foregroundStyle(gold)
            Text("原告胜诉概率")
                .font(.system(size: 13))
                .foregroundStyle(sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    // ④
    private var scoreCard: some View {
        VStack(spacing: 12) {
            scoreRow(name: Theme.speakerName("plaintiff"),
                     total: verdict.dimensionScores?["plaintiff"]?.total, color: gold)
            scoreRow(name: Theme.speakerName("defendant"),
                     total: verdict.dimensionScores?["defendant"]?.total, color: blue)
        }
        .padding(16)
        .background(card)
        .cornerRadius(14)
        .padding(.bottom, 14)
    }

    private func scoreRow(name: String, total: Double?, color: Color) -> some View {
        HStack(spacing: 10) {
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(main)
                .frame(width: 34, alignment: .leading)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * barFraction(total))
                }
            }
            .frame(height: 10)
            Text(total.map { String(Int($0.rounded())) } ?? "--")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .frame(width: 32, alignment: .trailing)
        }
    }

    /// 评分总量按 0–100 满分映射为条宽（越界截断）。
    private func barFraction(_ total: Double?) -> CGFloat {
        guard let total, total > 0 else { return 0 }
        return CGFloat(min(total / 100.0, 1.0))
    }

    // ⑤
    private var conclusionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("核心结论")
                .font(.system(size: 12, weight: .bold))
                .tracking(2)
                .foregroundStyle(gold)
            Text(summaryText)
                .font(.system(size: 15))
                .foregroundStyle(main)
                .lineSpacing(5)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(card)
        .cornerRadius(14)
    }

    // ⑥
    private var footer: some View {
        VStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.1)).frame(height: 1)
            HStack {
                Text("引用法条 \(verdict.legalProvisions?.count ?? 0) 条")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(gold)
                Spacer()
                Text("辩坛 AI·AI 生成内容仅供研究参考")
                    .font(.system(size: 10))
                    .foregroundStyle(sub)
            }
        }
    }
}
