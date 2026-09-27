import SwiftUI

/// 像素法庭舞台：Canvas 绘制四角色像素小人 + 打字机对白 + 双方 HP + 异议横幅。
/// 数据流：父视图（DebateView）在每次推进后更新这些属性即可。
struct PixelCourtView: View {
    var speaker: String
    var text: String
    var stepText: String
    var hpPlaintiff: Double?
    var hpDefendant: Double?
    var objection: Bool

    // 打字机：text 变化即重置起始时间
    @State private var typeStart: Date = .now
    @State private var typedText: String = ""
    @State private var lastText: String = ""
    @State private var objectionUntil: Date = .distantPast

    private let pal: [String: Color] = [
        "k": Color(red: 0.07, green: 0.09, blue: 0.15),
        "w": Color(red: 0.96, green: 0.94, blue: 0.90),
        "W": .white,
        "s": Color(red: 0.91, green: 0.73, blue: 0.55),
        "b": Color(red: 0.11, green: 0.31, blue: 0.85),
        "B": Color(red: 0.15, green: 0.39, blue: 0.92),
        "r": Color(red: 0.50, green: 0.11, blue: 0.11),
        "R": Color(red: 0.73, green: 0.11, blue: 0.11),
        "g": Color(red: 0.83, green: 0.63, blue: 0.09),
        "G": Color(red: 0.94, green: 0.79, blue: 0.29),
        "d": Color(red: 0.06, green: 0.09, blue: 0.16),
        "h": Color(red: 0.29, green: 0.21, blue: 0.13),
        "c": Color(red: 0.05, green: 0.65, blue: 0.63),
        "e": Color(red: 0.07, green: 0.07, blue: 0.07),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let now = timeline.date
            ZStack {
                courtBackground
                hpBars()
                sprites(now: now)
                objectionOverlay(now: now)
                dialogueBox(now: now)
            }
        }
        .background(Color(red: 0.04, green: 0.07, blue: 0.13))
        .onChange(of: text) { newValue in
            if newValue != lastText {
                lastText = newValue
                typeStart = .now
            }
        }
        .onChange(of: objection) { isObj in
            if isObj { objectionUntil = .now.addingTimeInterval(1.4) }
        }
    }

    // MARK: - 场景

    private var courtBackground: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: [Color(red: 0.09, green: 0.14, blue: 0.24),
                                    Color(red: 0.11, green: 0.17, blue: 0.30)],
                           startPoint: .top, endPoint: .bottom)
                .frame(height: 200)
            VStack { Spacer() }
            GeometryReader { geo in
                Path { p in
                    let floorY = geo.size.height * 0.72
                    p.move(to: CGPoint(x: 0, y: floorY))
                    p.addLine(to: CGPoint(x: geo.size.width, y: floorY))
                }
                .stroke(Color(red: 0.09, green: 0.06, blue: 0.04), lineWidth: 3)
                Rectangle()
                    .fill(LinearGradient(colors: [Color(red: 0.27, green: 0.21, blue: 0.13),
                                                  Color(red: 0.18, green: 0.13, blue: 0.08)],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: geo.size.height * 0.28)
                    .position(x: geo.size.width / 2,
                              y: geo.size.height * 0.72 + geo.size.height * 0.14)
            }
            Text("⚖️")
                .font(.system(size: 30))
                .shadow(color: .accentColor.opacity(0.5), radius: 8)
                .padding(.top, 8)
        }
    }

    private func hpBars() -> some View {
        HStack {
            hpBar(name: "原告 HP", value: hpPlaintiff ?? 100,
                  fill: LinearGradient(colors: [Theme.accent, Color(red: 0.2, green: 0.88, blue: 0.72)],
                                       startPoint: .leading, endPoint: .trailing))
            Spacer()
            Text(stepText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(Theme.gold)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Theme.card)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.line, lineWidth: 1))
            Spacer()
            hpBar(name: "被告 HP", value: hpDefendant ?? 100,
                  fill: LinearGradient(colors: [Theme.danger, .orange],
                                       startPoint: .leading, endPoint: .trailing))
        }
        .padding(10)
        .zIndex(5)
    }

    private func hpBar(name: String, value: Double, fill: LinearGradient) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name).font(.system(size: 9, design: .monospaced)).foregroundColor(Theme.textSub)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Theme.card)
                    Rectangle().fill(fill).frame(width: max(0, min(100, value)) / 100 * geo.size.width)
                }
            }
            .frame(height: 9)
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.line, lineWidth: 2))
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .frame(maxWidth: 130)
    }

    // MARK: - 角色

    private struct SpriteSpec {
        let id: String
        let rows: [String]
        let name: String
        let scale: CGFloat
        let alignment: Alignment
        let offsetY: CGFloat
        let flip: Bool
    }

    private var spriteSpecs: [SpriteSpec] {
        [
            SpriteSpec(id: "plaintiff", rows: Self.person(suit: "B", trim: "b"), name: "正方",
                       scale: 9, alignment: .bottomLeading, offsetY: -90, flip: false),
            SpriteSpec(id: "defendant", rows: Self.person(suit: "R", trim: "r"), name: "反方",
                       scale: 9, alignment: .bottomTrailing, offsetY: -90, flip: true),
            SpriteSpec(id: "judge", rows: Self.judge(), name: "裁判长",
                       scale: 10, alignment: .center, offsetY: 0, flip: false),
            SpriteSpec(id: "clerk", rows: Self.clerk(), name: "书记员",
                       scale: 7, alignment: .bottomTrailing, offsetY: -40, flip: false),
        ]
    }

    private func sprites(now: Date) -> some View {
        ZStack {
            ForEach(spriteSpecs, id: \.id) { spec in
                let active = (spec.id == speaker)
                let bounce = active ? CGFloat(now.timeIntervalSince1970.truncatingRemainder(dividingBy: 0.5) * 16 - 4) : 0
                VStack(spacing: 4) {
                    Text(spec.name)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(active ? Theme.accent : Theme.textSub)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.card)
                        .cornerRadius(4)
                        .overlay(RoundedRectangle(cornerRadius: 4)
                            .stroke(active ? Theme.accent : Theme.line, lineWidth: 1))
                    spriteCanvas(rows: spec.rows, scale: spec.scale)
                        .scaleEffect(x: spec.flip ? -1 : 1, y: 1)
                        .opacity(active ? 1 : 0.45)
                        .shadow(color: active ? Theme.accent.opacity(0.55) : .clear, radius: 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: spec.alignment)
                .offset(y: spec.offsetY + bounce)
            }
        }
    }

    private func spriteCanvas(rows: [String], scale: CGFloat) -> some View {
        Canvas { context, _ in
            let h = rows.count
            for y in 0..<h {
                let rowChars = Array(rows[y])
                for x in 0..<rowChars.count {
                    if let color = pal[String(rowChars[x])] {
                        let rect = CGRect(x: CGFloat(x) * scale, y: CGFloat(y) * scale,
                                          width: scale * 1.02, height: scale * 1.02)
                        context.fill(Path(rect), with: .color(color))
                    }
                }
            }
        }
        .frame(width: CGFloat(rows.map(\.count).max() ?? 0) * scale,
               height: CGFloat(rows.count) * scale)
    }

    private func objectionOverlay(now: Date) -> some View {
        Group {
            if now < objectionUntil {
                Text("异 议 !")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .italic()
                    .foregroundColor(Color(red: 1, green: 0.3, blue: 0.3))
                    .shadow(color: Color(red: 0.3, green: 0.02, blue: 0.02), radius: 0, x: 4, y: 4)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .zIndex(9)
    }

    // MARK: - 对白框

    private func dialogueBox(now: Date) -> some View {
        let elapsed = now.timeIntervalSince(typeStart)
        let charCount = min(Int(elapsed / 0.03), lastText.count)
        let shown = String(lastText.prefix(charCount))
        let name = Theme.speakerName(speaker)
        return VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.background)
                .padding(.horizontal, 10)
                .padding(.vertical, 2)
                .background(Theme.accent)
                .cornerRadius(5)
            Text(shown)
                .font(.system(size: 13))
                .foregroundColor(Color.white)
                .lineSpacing(4)
                .frame(minHeight: 56, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card.opacity(0.96))
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 3))
        .overlay(alignment: .topLeading) {
            EmptyView()
        }
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
        .zIndex(6)
    }

    // MARK: - 像素矩阵（与 Web 版像素法庭同源）

    private static func person(suit: String, trim: String) -> [String] {
        [
            "....ssss....",
            "...ssssss...",
            "....sees....",
            "....ssss....",
            "...hhhhhh...",
            "..\(suit)\(suit)\(suit)\(suit)\(suit)\(suit)..",
            ".\(suit)\(suit)\(trim)\(suit)\(suit)\(suit)\(suit)\(trim)\(suit)\(suit).",
            ".\(suit)ss\(suit)\(suit)\(suit)\(suit)ss\(suit).",
            ".\(suit)ss\(suit)\(suit)\(suit)\(suit)ss\(suit).",
            "..\(suit)\(suit)\(suit)\(suit)\(suit)\(suit)..",
            "..\(trim)\(trim)\(trim)..\(trim)\(trim)\(trim)..",
            "..\(trim)\(trim)\(trim)..\(trim)\(trim)\(trim)..",
            "..kkk..kkk..",
            "..kkk..kkk..",
            "............",
        ]
    }

    private static func judge() -> [String] {
        [
            "....wwww....",
            "...wwwwww...",
            "...wssssw...",
            "...wseesw...",
            "...wssssw...",
            "..rrrrrrrr..",
            ".rrrRggRrrr.",
            "rrrrRggRrrrr",
            "rrrrrrrrrrrr",
            "rrrrrrrrrrrr",
            ".rrrrrrrrrr.",
            "..dddddddd..",
            "..dddddddd..",
            "..d..dd..d..",
            "..d..dd..d..",
        ]
    }

    private static func clerk() -> [String] {
        [
            "....ssss....",
            "...ssssss...",
            "....sees....",
            "....ssss....",
            "...cccccc...",
            "..cccccccc..",
            ".ccCCCCCCcc.",
            "...cccccc...",
            "...cccccc...",
            "...cccccc...",
            "....dddd....",
            "...dddddd...",
            "...dddddd...",
            "....d..d....",
            "............",
        ]
    }
}
