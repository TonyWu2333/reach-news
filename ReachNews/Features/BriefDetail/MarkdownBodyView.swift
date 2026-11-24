import SwiftUI
import Markdown

// MARK: - 正文 Markdown 渲染
//
// 服务端把正文写在 segments[].text 里，内容是 AI 按技能模板生成的 Markdown，
// 语法不受逐字控制（会出现小标题、列表、代码块等）。因此这里接入 Apple 官方
// 的 swift-markdown（CommonMark 参考实现）解析，再把 AST 映射成 SwiftUI 视图，
// 不自研正则，也不做「只认 ## 和 **」的最小实现。
//
// 渲染范围严格限定 body：title / summary / sections 一律纯文本，不走这里。

/// 把一个 Markdown 源码片段渲染成视图块序列。
struct MarkdownBodyView: View {
    let markdown: String
    var onOpenURL: (URL) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                block
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.openURL, OpenURLAction { url in
            onOpenURL(url)
            return .handled
        })
    }

    /// 解析一次，得到有序的块级视图。
    private var blocks: [AnyView] {
        let document = Document(parsing: markdown)
        var renderer = MarkdownBlockRenderer()
        return renderer.visit(document)
    }
}

// MARK: - 块级渲染
//
// 只处理正文可能出现的块：标题、段落、列表、引用、代码块、分隔线。
// 未知块按段落降级，保证内容不丢。

struct MarkdownBlockRenderer: MarkupVisitor {
    typealias Result = [AnyView]

    mutating func defaultVisit(_ markup: Markup) -> [AnyView] {
        // 未知块：把它的子节点铺平，避免内容消失。
        // 注意不能写成 children.flatMap { visit($0) }：闭包里 self 是只读的，mutating 方法调不了。
        flattened(markup)
    }

    mutating func visitDocument(_ document: Document) -> [AnyView] {
        flattened(document)
    }

    /// 递归铺平子节点的块视图。
    private mutating func flattened(_ markup: Markup) -> [AnyView] {
        var result: [AnyView] = []
        for child in markup.children {
            result.append(contentsOf: visit(child))
        }
        return result
    }

    mutating func visitParagraph(_ paragraph: Paragraph) -> [AnyView] {
        [AnyView(
            Text(inlineAttributed(for: paragraph))
                .font(TypeFace.body(16))
                .lineSpacing(7)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        )]
    }

    mutating func visitHeading(_ heading: Heading) -> [AnyView] {
        // 正文里的小标题：按级别给字号，保持层级感但不喧宾夺主。
        let size: CGFloat
        switch heading.level {
        case 1: size = 22
        case 2: size = 19
        case 3: size = 17
        default: size = 16
        }
        return [AnyView(
            Text(inlineAttributed(for: heading))
                .font(TypeFace.heading(size))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Space.xs)
                .accessibilityAddTraits(.isHeader)
        )]
    }

    mutating func visitUnorderedList(_ list: UnorderedList) -> [AnyView] {
        listItems(list, marker: "•")
    }

    mutating func visitOrderedList(_ list: OrderedList) -> [AnyView] {
        // startIndex 在 swift-markdown 里不是 public，外部读不到；
        // 正文的有序列表从 1 开始编号即可，无需还原自定义起始值。
        var result: [AnyView] = []
        for (offset, child) in list.children.enumerated() {
            guard let item = child as? ListItem else {
                result.append(contentsOf: visit(child))
                continue
            }
            let body = itemBody(item)
            result.append(AnyView(
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text("\(offset + 1).")
                        .font(TypeFace.condensed(14, weight: .semibold))
                        .foregroundStyle(Palette.inkTertiary)
                        .frame(minWidth: 20, alignment: .trailing)
                    body
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            ))
        }
        return result
    }

    mutating func visitCodeBlock(_ codeBlock: CodeBlock) -> [AnyView] {
        // 等宽、保留换行与缩进；不做语法高亮。
        [AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                Text(codeBlock.code)
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
        )]
    }

    mutating func visitBlockQuote(_ blockQuote: BlockQuote) -> [AnyView] {
        let inner = flattened(blockQuote)
        return [AnyView(
            HStack(alignment: .top, spacing: Space.m) {
                Rectangle()
                    .fill(Palette.lineStrong)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: Space.s) {
                    ForEach(Array(inner.enumerated()), id: \.offset) { _, view in view }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Space.xxs)
        )]
    }

    mutating func visitThematicBreak(_ thematicBreak: ThematicBreak) -> [AnyView] {
        [AnyView(
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
                .padding(.vertical, Space.xs)
        )]
    }

    // MARK: 辅助

    private mutating func listItems(_ list: Markup, marker: String) -> [AnyView] {
        var result: [AnyView] = []
        for child in list.children {
            guard let item = child as? ListItem else {
                result.append(contentsOf: visit(child))
                continue
            }
            let body = itemBody(item)
            result.append(AnyView(
                HStack(alignment: .firstTextBaseline, spacing: Space.s) {
                    Text(marker)
                        .font(TypeFace.body(16))
                        .foregroundStyle(Palette.inkTertiary)
                    body
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            ))
        }
        return result
    }

    /// 列表项内部可能还有嵌套段落与子列表，递归取块视图。
    /// 返回 AnyView 而不是 some View：调用方处在 mutating 上下文里，
    /// 返回不透明类型会把 mutating 访问泄漏到视图构建过程中。
    private mutating func itemBody(_ item: ListItem) -> AnyView {
        var inner: [AnyView] = []
        for child in item.children {
            inner.append(contentsOf: visit(child))
        }
        return AnyView(
            VStack(alignment: .leading, spacing: Space.xs) {
                ForEach(Array(inner.enumerated()), id: \.offset) { _, view in
                    view
                }
            }
        )
    }

    /// 行内样式（粗体、斜体、代码、链接）合成一个 AttributedString。
    private func inlineAttributed(for markup: Markup) -> AttributedString {
        var visitor = MarkdownInlineRenderer()
        var result = AttributedString()
        for child in markup.children {
            result += visitor.visit(child)
        }
        return result
    }
}

// MARK: - 行内渲染
//
// 行内元素合成富文本：粗体、斜体、行内代码、链接、删除线、换行。

struct MarkdownInlineRenderer: MarkupVisitor {
    typealias Result = AttributedString

    mutating func defaultVisit(_ markup: Markup) -> AttributedString {
        // 同样不能在 reduce/遍历闭包里调用 mutating 的 visit。
        var result = AttributedString()
        for child in markup.children {
            result += visit(child)
        }
        return result
    }

    mutating func visitText(_ text: Text) -> AttributedString {
        AttributedString(text.string)
    }

    mutating func visitStrong(_ strong: Strong) -> AttributedString {
        var result = defaultVisit(strong)
        result.inlinePresentationIntent = .stronglyEmphasized
        return result
    }

    mutating func visitEmphasis(_ emphasis: Emphasis) -> AttributedString {
        var result = defaultVisit(emphasis)
        result.inlinePresentationIntent = .emphasized
        return result
    }

    mutating func visitInlineCode(_ inlineCode: InlineCode) -> AttributedString {
        var result = AttributedString(inlineCode.code)
        result.inlinePresentationIntent = .code
        result.foregroundColor = Palette.inkSecondary
        return result
    }

    mutating func visitStrikethrough(_ strikethrough: Strikethrough) -> AttributedString {
        var result = defaultVisit(strikethrough)
        result.inlinePresentationIntent = .strikethrough
        return result
    }

    mutating func visitLink(_ link: Link) -> AttributedString {
        var result = defaultVisit(link)
        if let destination = link.destination, let url = URL(string: destination) {
            result.link = url
            result.underlineStyle = .single
            result.foregroundColor = Palette.runningForeground
        }
        return result
    }

    mutating func visitLineBreak(_ lineBreak: LineBreak) -> AttributedString {
        AttributedString("\n")
    }

    mutating func visitSoftBreak(_ softBreak: SoftBreak) -> AttributedString {
        // 软换行在段落里按空格处理，避免把一段话拆成多行。
        AttributedString(" ")
    }
}
