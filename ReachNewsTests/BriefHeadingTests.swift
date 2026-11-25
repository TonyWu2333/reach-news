import XCTest
import SwiftUI
@testable import ReachNews

// MARK: - 正文小标题
//
// 服务端没有「小标题对应哪条素材」的字段，「查看原文」只能按文字判断。
// 这里覆盖匹配规则、未命中时不出现该项、以及事件频道的预填内容。

final class BriefHeadingTests: XCTestCase {

    // MARK: 匹配规则

    func testHeadingIsContainedInMaterialTitle() {
        XCTAssertTrue(
            HeadingSourceMatcher.matches(
                heading: "模型竞赛进入下半场",
                materialTitle: "模型竞赛进入下半场：三家同时放出长上下文版本"
            )
        )
    }

    func testMatchingIgnoresCaseOnly() {
        XCTAssertTrue(
            HeadingSourceMatcher.matches(heading: "vllm", materialTitle: "vLLM 推理性能翻倍的那次合并")
        )
        // 需求限定「只忽略大小写」：变音符号不视为相同字符，不做模糊归一。
        XCTAssertFalse(
            HeadingSourceMatcher.matches(heading: "CAFE", materialTitle: "Café 里的那段对话")
        )
    }

    func testUnrelatedTitleDoesNotMatch() {
        XCTAssertFalse(
            HeadingSourceMatcher.matches(heading: "算力租赁价格", materialTitle: "开源模型的许可证正在收紧")
        )
    }

    func testEmptyHeadingNeverMatches() {
        XCTAssertFalse(HeadingSourceMatcher.matches(heading: "   ", materialTitle: "任意标题"))
        XCTAssertFalse(HeadingSourceMatcher.matches(heading: "", materialTitle: ""))
    }

    func testHeadingIsOnlyTrimmedNotRewritten() {
        // 只裁首尾空白，不改写文字：去掉冒号之类会让匹配结果难以解释。
        XCTAssertEqual(HeadingSourceMatcher.normalizedHeading("  来源  "), "来源")
        XCTAssertEqual(HeadingSourceMatcher.normalizedHeading("来源："), "来源：")
        XCTAssertFalse(
            HeadingSourceMatcher.matches(heading: "来源：", materialTitle: "来源梳理")
        )
    }

    func testFirstMatchWinsWhenSeveralCandidatesMatch() {
        let candidates = [
            BriefHeadingCandidate(itemID: "m1", materialTitle: "无关标题", materialURL: URL(string: "https://a.test/1")),
            BriefHeadingCandidate(itemID: "m2", materialTitle: "事件进展一", materialURL: URL(string: "https://a.test/2")),
            BriefHeadingCandidate(itemID: "m3", materialTitle: "事件进展二", materialURL: URL(string: "https://a.test/3"))
        ]

        let match = HeadingSourceMatcher.firstMatch(heading: "事件进展", candidates: candidates)

        XCTAssertEqual(match?.itemID, "m2")
        XCTAssertEqual(match?.materialURL?.absoluteString, "https://a.test/2")
    }

    func testNoMatchReturnsNilSoTheSourceOptionIsHidden() {
        let candidates = [
            BriefHeadingCandidate(itemID: "m1", materialTitle: "无关标题", materialURL: URL(string: "https://a.test/1"))
        ]

        XCTAssertNil(HeadingSourceMatcher.firstMatch(heading: "事件进展", candidates: candidates))
    }

    func testUnresolvedCandidateDoesNotMatch() {
        // 素材取不回来（离线 / 404）时标题为 nil，不能装作命中。
        let candidates = [BriefHeadingCandidate(itemID: "m1", materialTitle: nil, materialURL: nil)]

        XCTAssertNil(HeadingSourceMatcher.firstMatch(heading: "任何标题", candidates: candidates))
        XCTAssertFalse(candidates[0].isResolved)
    }

    // MARK: 动作层选项

    func testActionsIncludeOpenSourceOnlyWhenMatched() {
        let withSource = HeadingActionContext(
            heading: "事件进展",
            sourceURL: URL(string: "https://a.test/1"),
            locale: Locale(identifier: "zh-Hans")
        )
        XCTAssertEqual(HeadingActionPlanner.actions(for: withSource), [.openSource, .trackEvent])
    }

    func testActionsFallBackToTrackEventOnly() {
        let withoutSource = HeadingActionContext(
            heading: "事件进展",
            sourceURL: nil,
            locale: Locale(identifier: "zh-Hans")
        )
        // 未命中时只剩跟踪事件，且永远不是空列表——不会出现空白项或死入口。
        XCTAssertEqual(HeadingActionPlanner.actions(for: withoutSource), [.trackEvent])
        XCTAssertFalse(HeadingActionPlanner.actions(for: withoutSource).isEmpty)
    }

    // MARK: 事件预填

    func testEventDraftNameUsesHeadingText() {
        XCTAssertEqual(TrackedEventDraft.name(heading: "  模型竞赛进入下半场  "), "模型竞赛进入下半场")
    }

    func testEventDraftPromptEmbedsHeading() {
        let prompt = TrackedEventDraft.prompt(heading: "模型竞赛进入下半场", locale: Locale(identifier: "zh-Hans"))

        XCTAssertTrue(prompt.contains("模型竞赛进入下半场"))
        XCTAssertFalse(prompt.isEmpty)
        // 模板里不该残留未替换的占位符。
        XCTAssertFalse(prompt.contains("%@"))
    }

    func testEventDraftPromptIsLocalized() {
        let en = TrackedEventDraft.prompt(heading: "Model race", locale: Locale(identifier: "en"))
        let zh = TrackedEventDraft.prompt(heading: "Model race", locale: Locale(identifier: "zh-Hans"))

        XCTAssertTrue(en.contains("Model race"))
        XCTAssertNotEqual(en, zh)
    }
}

// MARK: - 正文链接着色
//
// 用户最初的报障是「链接看不见」。全局 tint 是近黑色，同段 Text 又带
// .foregroundStyle(Palette.ink)，仅靠 tint 无法保证链接可辨。
// 现在把颜色直接写进链接 run——这是纯 AttributedString 属性，
// 不需要渲染就能断言，因此可以让 CI 证明「颜色确实写进去了」。

final class BriefLinkColoringTests: XCTestCase {

    private func attributed(_ markdown: String) -> AttributedString {
        MarkdownBlockBuilder.attributed(from: markdown)
    }

    func testLinkRunsGetTheLinkColor() {
        let colored = MarkdownBlockBuilder.coloringLinks(
            attributed("看这条 [原文](https://example.test/a) 的报道。")
        )

        let linked = colored.runs.filter { $0.link != nil }
        XCTAssertFalse(linked.isEmpty, "markdown 里的链接应当产生 link run")
        for run in linked {
            XCTAssertEqual(run.foregroundColor, Palette.link)
        }
    }

    func testNonLinkRunsKeepTheirColor() {
        let source = attributed("普通文字，与 [链接](https://example.test/a)。")
        let colored = MarkdownBlockBuilder.coloringLinks(source)

        // 非链接 run 不应被改成链接色：正文颜色由视图层决定，这里不能越权。
        let plain = colored.runs.filter { $0.link == nil }
        XCTAssertFalse(plain.isEmpty)
        for run in plain {
            XCTAssertNotEqual(run.foregroundColor, Palette.link)
        }
    }

    func testTextWithoutLinksIsUnchanged() {
        let source = attributed("只有正文，没有任何链接。")
        let colored = MarkdownBlockBuilder.coloringLinks(source)

        XCTAssertEqual(String(colored.characters), String(source.characters))
        for run in colored.runs {
            XCTAssertNil(run.foregroundColor)
        }
    }

    func testSplitAppliesColoringToEveryBlock() {
        // 标题、段落、列表里的链接都要着色，不能只处理某一种块类型。
        let markdown = """
        ## 小标题

        段落里有 [链接一](https://example.test/1)。

        - 列表里有 [链接二](https://example.test/2)
        """
        let blocks = MarkdownBlockBuilder.split(attributed(markdown))

        let allLinkRuns = blocks.flatMap { $0.text.runs.filter { $0.link != nil } }
        XCTAssertFalse(allLinkRuns.isEmpty)
        for run in allLinkRuns {
            XCTAssertEqual(run.foregroundColor, Palette.link)
        }
    }
}
