import XCTest
import Markdown
@testable import ReachNews

// MARK: - 正文 Markdown 渲染
//
// 正文的 segments[].text 是 AI 生成的 Markdown，语法不受逐字控制。
// 这里用真实的 swift-markdown 解析器验证：各类语法都能被识别为对应节点，
// 而不是留在文本里变成字面的 ## / - / ```。
//
// 同时验证渲染范围只限 body：title / summary / sections 走纯文本。

final class MarkdownBodyTests: XCTestCase {

    // MARK: 块级语法

    func testHeadingParsesAsHeadingNode() {
        let document = Document(parsing: "## 一句话结论")
        let heading = document.children.compactMap { $0 as? Heading }.first

        XCTAssertNotNil(heading, "## 应被解析为 Heading，而不是字面文字")
        XCTAssertEqual(heading?.level, 2)
        XCTAssertEqual(heading?.plainText, "一句话结论")
    }

    func testHeadingLevelsArePreserved() {
        for level in 1...6 {
            let document = Document(parsing: String(repeating: "#", count: level) + " 标题")
            let heading = document.children.compactMap { $0 as? Heading }.first
            XCTAssertEqual(heading?.level, level, "标题级别应保持为 \(level)")
        }
    }

    func testUnorderedListParsesAsList() {
        let markdown = """
        - 第一条
        - 第二条
        - 第三条
        """
        let document = Document(parsing: markdown)
        let list = document.children.compactMap { $0 as? UnorderedList }.first

        XCTAssertNotNil(list, "无序列表应被解析为 UnorderedList")
        XCTAssertEqual(list?.children.count, 3)
    }

    func testOrderedListParsesAsList() {
        let markdown = """
        1. 准备
        2. 执行
        3. 复核
        """
        let document = Document(parsing: markdown)
        let list = document.children.compactMap { $0 as? OrderedList }.first

        XCTAssertNotNil(list, "有序列表应被解析为 OrderedList")
        XCTAssertEqual(list?.children.count, 3)
    }

    func testFencedCodeBlockKeepsContent() {
        let markdown = """
        ```swift
        let x = 1
        print(x)
        ```
        """
        let document = Document(parsing: markdown)
        let code = document.children.compactMap { $0 as? CodeBlock }.first

        XCTAssertNotNil(code, "围栏代码块应被解析为 CodeBlock")
        XCTAssertEqual(code?.language, "swift")
        XCTAssertTrue(code?.code.contains("let x = 1") ?? false)
        XCTAssertFalse(code?.code.contains("```") ?? true, "代码块里不应残留围栏标记")
    }

    func testIndentedCodeBlockParses() {
        let markdown = "    缩进代码"
        let document = Document(parsing: markdown)
        XCTAssertNotNil(document.children.compactMap { $0 as? CodeBlock }.first)
    }

    func testBlockQuoteParses() {
        let markdown = "> 引用的一段话"
        let document = Document(parsing: markdown)
        XCTAssertNotNil(document.children.compactMap { $0 as? BlockQuote }.first)
    }

    func testThematicBreakParses() {
        let document = Document(parsing: "---")
        XCTAssertNotNil(document.children.compactMap { $0 as? ThematicBreak }.first)
    }

    func testParagraphParses() {
        let document = Document(parsing: "只是一段普通文字。")
        XCTAssertNotNil(document.children.compactMap { $0 as? Paragraph }.first)
    }

    // MARK: 行内语法

    func testStrongParsesInsideParagraph() {
        let document = Document(parsing: "这是**重点**内容")
        let strong = findFirst(Strong.self, in: document)
        XCTAssertNotNil(strong, "**粗体** 应被解析为 Strong")
        XCTAssertEqual(strong?.plainText, "重点")
    }

    func testEmphasisParsesInsideParagraph() {
        let document = Document(parsing: "这是*斜体*内容")
        let emphasis = findFirst(Emphasis.self, in: document)
        XCTAssertNotNil(emphasis, "*斜体* 应被解析为 Emphasis")
        XCTAssertEqual(emphasis?.plainText, "斜体")
    }

    func testInlineCodeParses() {
        let document = Document(parsing: "调用 `build()` 方法")
        let code = findFirst(InlineCode.self, in: document)
        XCTAssertNotNil(code, "行内代码应被解析为 InlineCode")
        XCTAssertEqual(code?.code, "build()")
    }

    func testLinkParsesWithDestination() {
        let document = Document(parsing: "见 [原文](https://e.test/a)")
        let link = findFirst(Link.self, in: document)

        XCTAssertNotNil(link, "链接应被解析为 Link")
        XCTAssertEqual(link?.destination, "https://e.test/a")
        XCTAssertEqual(link?.plainText, "原文")
    }

    func testStrikethroughParses() {
        let document = Document(parsing: "~~过时~~")
        XCTAssertNotNil(findFirst(Strikethrough.self, in: document))
    }

    // MARK: 混合与边界

    func testMixedSyntaxInOneIssue() {
        // 一期真实正文可能同时出现多种语法；全部都要被识别。
        let markdown = """
        ## 结论

        本期值得看的是**两件事**，都跟 `OpenSSL` 有关。

        - 修复已经合入
        - 影响 EVP_EncodeBlock

        > 建议尽快升级。

        ```
        openssl version
        ```

        详见 [原文](https://e.test/openssl)。
        """
        let document = Document(parsing: markdown)

        XCTAssertNotNil(document.children.compactMap { $0 as? Heading }.first)
        XCTAssertNotNil(findFirst(Strong.self, in: document))
        XCTAssertNotNil(findFirst(InlineCode.self, in: document))
        XCTAssertNotNil(document.children.compactMap { $0 as? UnorderedList }.first)
        XCTAssertNotNil(document.children.compactMap { $0 as? BlockQuote }.first)
        XCTAssertNotNil(document.children.compactMap { $0 as? CodeBlock }.first)
        XCTAssertNotNil(findFirst(Link.self, in: document))
    }

    func testPlainTextWithoutMarkupStillRendersAsParagraph() {
        let document = Document(parsing: "没有任何标记的一句话。")
        let paragraph = document.children.compactMap { $0 as? Paragraph }.first
        XCTAssertNotNil(paragraph)
        XCTAssertEqual(paragraph?.plainText, "没有任何标记的一句话。")
    }

    func testLiteralMarkersInsideInlineCodeAreNotParsedAsBlocks() {
        // 行内代码里的 `##` 不该变成标题。
        let document = Document(parsing: "写作 `## 不是标题` 这样的片段")
        XCTAssertNil(document.children.compactMap { $0 as? Heading }.first)
        XCTAssertEqual(findFirst(InlineCode.self, in: document)?.code, "## 不是标题")
    }

    // MARK: 正文汇编

    func testBodyAssemblesSegmentsIntoMarkdown() {
        let body = BriefBody(paragraphs: [
            BriefParagraph(segments: [.text("## 结论")]),
            BriefParagraph(segments: [
                .text("详见 "),
                .link(text: "原文", url: URL(string: "https://e.test/a")!, itemID: "itm_1"),
                .text("。")
            ])
        ])

        let markdown = body.markdown

        // 段落之间空行分隔；结构化 link 拼回 Markdown 链接语法。
        XCTAssertTrue(markdown.contains("## 结论"))
        XCTAssertTrue(markdown.contains("[原文](https://e.test/a)"))

        // 拼出来的源码再解析，应得到标题、段落与链接。
        let document = Document(parsing: markdown)
        XCTAssertNotNil(document.children.compactMap { $0 as? Heading }.first)
        XCTAssertNotNil(findFirst(Link.self, in: document))
    }

    func testBodyMarkdownKeepsParagraphBoundaries() {
        let body = BriefBody(paragraphs: [
            BriefParagraph(segments: [.text("第一段")]),
            BriefParagraph(segments: [.text("第二段")])
        ])
        let document = Document(parsing: body.markdown)
        let paragraphs = document.children.compactMap { $0 as? Paragraph }

        // 空行分隔，两段不会被粘成一段。
        XCTAssertEqual(paragraphs.count, 2)
    }

    // MARK: 渲染范围只限 body

    func testTitleAndSummaryAreNotMarkdown() throws {
        // 即使 title / summary 里出现 Markdown 标记，界面也按纯文本显示：
        // 它们不经过 MarkdownBodyView，这里断言数据层原样保留标记。
        let json = """
        {"id":"brf_scope","channelId":"chn_1","title":"## 不是标题","summary":"**不是粗体**",
         "body":{"paragraphs":[{"segments":[{"type":"text","text":"## 正文标题"}]}]},
         "sections":[{"title":"**分组**","items":[{"title":"# 条目","summary":"*摘要*","itemIds":[]}]}],
         "memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        // 原样保留，未被提前解析或剥掉标记。
        XCTAssertEqual(brief.title, "## 不是标题")
        XCTAssertEqual(brief.displaySummary, "**不是粗体**")
        XCTAssertEqual(brief.sections.first?.title, "**分组**")
        XCTAssertEqual(brief.sections.first?.entries.first?.title, "# 条目")
        XCTAssertEqual(brief.sections.first?.entries.first?.summary, "*摘要*")

        // 只有正文被当作 Markdown。
        XCTAssertEqual(brief.body?.paragraphs.first?.segments.first?.displayText, "## 正文标题")
    }

    // MARK: 辅助

    /// 在整棵树里找第一个指定类型节点。
    private func findFirst<T: Markup>(_ type: T.Type, in markup: Markup) -> T? {
        if let match = markup as? T { return match }
        for child in markup.children {
            if let found = findFirst(type, in: child) { return found }
        }
        return nil
    }
}
