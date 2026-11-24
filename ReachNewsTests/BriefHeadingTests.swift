import XCTest
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
