import SwiftUI
import Foundation

// MARK: - 正文 Markdown 渲染（原生实现）
//
// 正文的 segments[].text 是 AI 按技能模板生成的 Markdown，语法不受逐字控制，
// 会出现标题、列表、代码块等——只认 ## 和 ** 的最小实现必然漏语法。
//
// 这里用 Foundation 自带的 CommonMark 解析器 `AttributedString(markdown:)`
// （interpretedSyntax: .full），不引入第三方依赖，也不自研正则。
//
// 它把 Markdown 解析成 AttributedString，块级结构记录在 `presentationIntent` 上：
// components 是从最外层到最内层的链（例如 [unorderedList, listItem]），
// `Text` 不会因为 intent 自动放大标题或缩进列表，所以这里按 intent 切块，
// 块级样式（标题字号、项目符号、代码底纹）由 SwiftUI 自己施加。
//
// 渲染范围严格限定 body：title / summary / sections 一律纯文本，不走这里。

struct MarkdownBodyView: View {
    let markdown: String
    var onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ForEach(Array(MarkdownBlockBuilder.parse(markdown).enumerated()), id: \.offset) { _, block in
                block
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            onOpenURL(url)
            return .handled
        })
    }
}

// MARK: - 分块与渲染

enum MarkdownBlockBuilder {

    /// 块级种类：取 intent 链里最深的那一层。
    enum Kind: Equatable {
        case paragraph
        case heading(level: Int)
        case listItem(ordered: Bool, ordinal: Int)
        case codeBlock
        case blockQuote
        case thematicBreak
    }

    struct Block {
        let kind: Kind
        let text: AttributedString
    }

    static func parse(_ markdown: String) -> [AnyView] {
        split(attributed(from: markdown)).map(view(for:))
    }

    /// Foundation 的 CommonMark 解析。失败时退回纯文本，保证正文不丢。
    static func attributed(from markdown: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let parsed = try? AttributedString(markdown: markdown, options: options) {
            return parsed
        }
        return AttributedString(markdown)
    }

    /// 按块级 intent 切分：intent 变一次就换块。
    static func split(_ attributed: AttributedString) -> [Block] {
        var blocks: [Block] = []
        var current = AttributedString()
        var currentKind: Kind = .paragraph

        func flush() {
            guard !current.characters.isEmpty else { return }
            let trimmed = trimmingEdges(current)
            if !trimmed.characters.isEmpty {
                blocks.append(Block(kind: currentKind, text: trimmed))
            }
            current = AttributedString()
        }

        for run in attributed.runs {
            let kind = kind(of: run.presentationIntent)
            if kind != currentKind {
                flush()
                currentKind = kind
            }
            // 保留行内样式即可；Text 不会因为块级 intent 自动加项目符号或放大标题，
            // 块级表现完全由下面的视图映射决定。
            current += AttributedString(attributed[run.range])
        }
        flush()
        return blocks
    }

    /// 从 intent 链判断该块的种类。
    ///
    /// 链是从最外层到最内层（例如列表项里的文字是 [unorderedList, listItem, paragraph]）。
    /// 因此不能只看最深一层：那样列表项会被当成普通段落而丢掉项目符号。
    /// 这里从内往外找第一个需要块级表现的种类，列表的有序性再由链里的容器决定。
    static func kind(of intent: PresentationIntent?) -> Kind {
        guard let components = intent?.components, !components.isEmpty else {
            return .paragraph
        }

        var isOrdered = false
        var isUnordered = false
        for component in components {
            switch component.kind {
            case .orderedList: isOrdered = true
            case .unorderedList: isUnordered = true
            default: break
            }
        }

        for component in components.reversed() {
            switch component.kind {
            case .header(let level):
                return .heading(level: level)
            case .listItem(let ordinal):
                return .listItem(ordered: isOrdered && !isUnordered, ordinal: ordinal)
            case .codeBlock:
                return .codeBlock
            case .blockQuote:
                return .blockQuote
            case .thematicBreak:
                return .thematicBreak
            default:
                continue
            }
        }
        return .paragraph
    }

    /// 去掉块首尾的空行与空格，避免段间出现多余留白。
    static func trimmingEdges(_ attributed: AttributedString) -> AttributedString {
        var result = attributed
        while let first = result.characters.first, first.isNewline || first == " " {
            result.removeSubrange(result.startIndex..<result.characters.index(after: result.startIndex))
        }
        while let last = result.characters.last, last.isNewline || last == " " {
            result.removeSubrange(result.characters.index(before: result.endIndex)..<result.endIndex)
        }
        return result
    }

    // MARK: 视图映射

    private static func view(for block: Block) -> AnyView {
        switch block.kind {
        case .heading(let level):
            let sizes: [CGFloat] = [22, 19, 17, 16, 16, 16]
            let size = sizes[min(max(level, 1), 6) - 1]
            return AnyView(
                Text(block.text)
                    .font(TypeFace.heading(size))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Space.xs)
                    .accessibilityAddTraits(.isHeader)
            )

        case .listItem(let ordered, let ordinal):
            let marker = ordered ? "\(max(ordinal, 1))." : "•"
            return AnyView(
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(marker)
                        .font(ordered ? TypeFace.condensed(14, weight: .semibold) : TypeFace.body(16))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(minWidth: 18, alignment: .trailing)
                    Text(block.text)
                        .font(TypeFace.body(16))
                        .lineSpacing(7)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )

        case .codeBlock:
            return AnyView(
                ScrollView(.horizontal, showsIndicators: false) {
                    // 代码块不加行内样式，等宽并保留换行与缩进；不做语法高亮。
                    Text(AttributedString(block.text.characters.map(String.init).joined()))
                        .font(.system(size: 13.5, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                        .textSelection(.enabled)
                        .padding(Space.m)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: Radius.medium, style: .continuous)
                        .fill(Palette.paper)
                )
            )

        case .blockQuote:
            return AnyView(
                HStack(alignment: .top, spacing: Space.m) {
                    Rectangle()
                        .fill(Palette.lineStrong)
                        .frame(width: 3)
                    Text(block.text)
                        .font(TypeFace.body(15))
                        .lineSpacing(6)
                        .foregroundStyle(Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            )

        case .thematicBreak:
            return AnyView(
                Rectangle()
                    .fill(Palette.line)
                    .frame(height: 1)
                    .padding(.vertical, Space.xs)
            )

        case .paragraph:
            return AnyView(
                Text(block.text)
                    .font(TypeFace.body(16))
                    .lineSpacing(7)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }
}
