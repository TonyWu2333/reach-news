import XCTest
import Foundation
@testable import ReachNews

// MARK: - 正文 Markdown 渲染（原生实现）
//
// 正文的 segments[].text 是 AI 生成的 Markdown，语法不受逐字控制。
// 这里用 Foundation 自带的 CommonMark 解析器（AttributedString(markdown:)）
// 验证：各类语法都能被识别为对应的块级种类，而不是留在文本里变成字面的 ## / - / ```。
//
// 同时验证渲染范围只限 body：title / summary / sections 走纯文本。

final class MarkdownBodyTests: XCTestCase {

    // MARK: 块级种类识别

    func testHeadingIsRecognisedAsHeading() {
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: "## 一句话结论"))

        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.kind, .heading(level: 2), "## 应识别为二级标题")
        XCTAssertEqual(plainText(of: blocks.first), "一句话结论")
    }

    func testHeadingLevelsArePreserved() {
        for level in 1...6 {
            let markdown = String(repeating: "#", count: level) + " 标题"
            let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: markdown))
            XCTAssertEqual(blocks.first?.kind, .heading(level: level), "标题级别应保持为 \(level)")
        }
    }

    func testUnorderedListItemsAreRecognised() {
        let markdown = """
        - 第一条
        - 第二条
        """
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: markdown))

        let items = blocks.filter { if case .listItem = $0.kind { return true }; return false }
        XCTAssertEqual(items.count, 2, "两个无序列表项应各自成块")
        // 无序列表不应被当成有序。
        XCTAssertFalse(items.contains { if case .listItem(let ordered, _) = $0.kind { return ordered }; return false })
    }

    func testOrderedListIsRecognisedAsOrdered() {
        let markdown = """
        1. 准备
        2. 执行
        """
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: markdown))

        let ordered = blocks.contains { if case .listItem(let isOrdered, _) = $0.kind { return isOrdered }; return false }
        XCTAssertTrue(ordered, "有序列表应标记为 ordered")
    }

    func testFencedCodeBlockKeepsContent() {
        let markdown = """
        ```swift
        let x = 1
        print(x)
        ```
        """
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: markdown))
        let code = blocks.first { $0.kind == .codeBlock }

        XCTAssertNotNil(code, "围栏代码块应识别为 codeBlock")
        let text = plainText(of: code)
        XCTAssertTrue(text.contains("let x = 1"), "代码内容应保留")
        XCTAssertFalse(text.contains("```"), "不应残留围栏标记")
    }

    func testBlockQuoteIsRecognised() {
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: "> 引用的一段话"))
        XCTAssertTrue(blocks.contains { $0.kind == .blockQuote })
    }

    func testThematicBreakIsRecognised() {
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: "---"))
        XCTAssertTrue(blocks.contains { $0.kind == .thematicBreak })
    }

    func testPlainParagraphStaysParagraph() {
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: "只是一段普通文字。"))
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.kind, .paragraph)
        XCTAssertEqual(plainText(of: blocks.first), "只是一段普通文字。")
    }

    // MARK: 行内语法

    func testStrongProducesInlineIntent() {
        let attributed = MarkdownBlockBuilder.attributed(from: "这是**重点**内容")
        let hasStrong = attributed.runs.contains { run in
            run.inlinePresentationIntent?.contains(.stronglyEmphasized) ?? false
        }
        XCTAssertTrue(hasStrong, "**粗体** 应产出 stronglyEmphasized 行内属性")
    }

    func testEmphasisProducesInlineIntent() {
        let attributed = MarkdownBlockBuilder.attributed(from: "这是*斜体*内容")
        let hasEmphasis = attributed.runs.contains { run in
            run.inlinePresentationIntent?.contains(.emphasized) ?? false
        }
        XCTAssertTrue(hasEmphasis, "*斜体* 应产出 emphasized 行内属性")
    }

    func testInlineCodeIsRecognised() {
        let attributed = MarkdownBlockBuilder.attributed(from: "调用 `build()` 方法")
        let hasCode = attributed.runs.contains { run in
            run.inlinePresentationIntent?.contains(.code) ?? false
        }
        XCTAssertTrue(hasCode, "行内代码应产出 code 行内属性")
    }

    func testLinkKeepsDestination() {
        let attributed = MarkdownBlockBuilder.attributed(from: "见 [原文](https://e.test/a)")
        let link = attributed.runs.compactMap(\.link).first
        XCTAssertEqual(link?.absoluteString, "https://e.test/a")
    }

    // MARK: 混合与边界

    func testMixedSyntaxInOneIssue() {
        // 一期真实正文可能同时出现多种语法，全部都要被识别。
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
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: markdown))

        XCTAssertTrue(blocks.contains { if case .heading(level: 2) = $0.kind { return true }; return false })
        XCTAssertTrue(blocks.contains { if case .listItem = $0.kind { return true }; return false })
        XCTAssertTrue(blocks.contains { $0.kind == .codeBlock })
        XCTAssertTrue(blocks.contains { $0.kind == .blockQuote })
        XCTAssertTrue(blocks.contains { $0.kind == .paragraph })
    }

    func testLiteralMarkerInsideInlineCodeIsNotABlock() {
        // 行内代码里的 ## 不该变成标题块。
        let attributed = MarkdownBlockBuilder.attributed(from: "写作 `## 不是标题` 这样的片段")
        let blocks = MarkdownBlockBuilder.split(attributed)

        XCTAssertFalse(blocks.contains { if case .heading = $0.kind { return true }; return false })
        XCTAssertEqual(blocks.count, 1)
        XCTAssertEqual(blocks.first?.kind, .paragraph)
    }

    func testEmptyMarkdownProducesNoBlocks() {
        XCTAssertTrue(MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: "")).isEmpty)
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
        XCTAssertTrue(markdown.contains("## 结论"))
        XCTAssertTrue(markdown.contains("[原文](https://e.test/a)"))

        // 拼出来的源码再解析，应得到标题块与带链接的段落。
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: markdown))
        XCTAssertTrue(blocks.contains { if case .heading = $0.kind { return true }; return false })
        XCTAssertTrue(blocks.contains { $0.text.runs.contains { $0.link != nil } })
    }

    func testBodyMarkdownKeepsParagraphBoundaries() {
        let body = BriefBody(paragraphs: [
            BriefParagraph(segments: [.text("第一段")]),
            BriefParagraph(segments: [.text("第二段")])
        ])
        let blocks = MarkdownBlockBuilder.split(MarkdownBlockBuilder.attributed(from: body.markdown))
        let paragraphs = blocks.filter { $0.kind == .paragraph }

        XCTAssertEqual(paragraphs.count, 2, "两段之间留空行，不应被粘成一段")
    }

    // MARK: 辅助

    /// AttributedString 的纯文本；缺块时返回空串。
    private func plainText(of block: MarkdownBlockBuilder.Block?) -> String {
        guard let block else { return "" }
        return String(block.text)
    }

    // MARK: 渲染范围只限 body

    func testTitleAndSummaryAreNotMarkdown() throws {
        // title / summary / sections 不经过 MarkdownBodyView：
        // 数据层原样保留标记，界面按纯文本显示。
        let json = """
        {"id":"brf_scope","channelId":"chn_1","title":"## 不是标题","summary":"**不是粗体**",
         "body":{"paragraphs":[{"segments":[{"type":"text","text":"## 正文标题"}]}]},
         "sections":[{"title":"**分组**","items":[{"title":"# 条目","summary":"*摘要*","itemIds":[]}]}],
         "memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        XCTAssertEqual(brief.title, "## 不是标题")
        XCTAssertEqual(brief.displaySummary, "**不是粗体**")
        XCTAssertEqual(brief.sections.first?.title, "**分组**")
        XCTAssertEqual(brief.sections.first?.entries.first?.title, "# 条目")
        XCTAssertEqual(brief.sections.first?.entries.first?.summary, "*摘要*")

        // 只有正文被当作 Markdown。
        XCTAssertEqual(brief.body?.paragraphs.first?.segments.first?.displayText, "## 正文标题")
    }
}
