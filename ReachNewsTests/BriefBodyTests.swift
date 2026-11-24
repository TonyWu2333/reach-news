import XCTest
@testable import ReachNews

// MARK: - 日报正文
//
// 覆盖 body 的三种状态（有正文 / null / 字段缺失）、片段解析与降级、
// summary 空值处理，以及「读者端不渲染 sections」所依赖的模型判定。
// 全部用固定响应或固定 JSON，不打网络。

final class BriefBodyTests: XCTestCase {

    // MARK: 解析：三种状态

    func testFixtureCoversAllBodyStates() throws {
        let data = try Fixture.data("briefs")
        let envelope = try JSONDecoder().decode(PageEnvelope<BriefDTO>.self, from: data)
        let briefs = envelope.items.map { $0.toDomain() }

        // 有正文、body 为 null、body 字段缺失三种样本都必须在。
        XCTAssertTrue(briefs.contains { $0.hasReadableBody })
        XCTAssertTrue(briefs.contains { $0.body == nil && $0.displaySummary == nil })
    }

    func testBodyWithParagraphsAndLinksDecodes() throws {
        let data = try Fixture.data("briefs")
        let envelope = try JSONDecoder().decode(PageEnvelope<BriefDTO>.self, from: data)
        let brief = try XCTUnwrap(envelope.items.map { $0.toDomain() }.first { $0.hasReadableBody })

        let body = try XCTUnwrap(brief.body)
        XCTAssertEqual(body.paragraphs.count, 2)

        let first = body.paragraphs[0]
        XCTAssertEqual(first.segments.count, 3)
        XCTAssertEqual(first.segments[0].displayText, "过去 24 小时最值得看的是 ")
        XCTAssertNil(first.segments[0].linkURL)

        let link = first.segments[1]
        XCTAssertEqual(link.displayText, "三家同时放出长上下文版本")
        XCTAssertEqual(link.linkURL?.absoluteString, "https://e.test/longctx")
        XCTAssertEqual(link.itemID, "itm_99d96709-2f41-4b3a-8c7e-1d5a9f0b3c14")

        let second = body.paragraphs[1]
        XCTAssertEqual(second.segments.count, 1)
        XCTAssertNil(second.segments[0].linkURL)
    }

    func testSummaryDecodesAndSurfacesAsDisplaySummary() throws {
        let data = try Fixture.data("briefs")
        let envelope = try JSONDecoder().decode(PageEnvelope<BriefDTO>.self, from: data)
        let brief = try XCTUnwrap(envelope.items.map { $0.toDomain() }.first { $0.displaySummary != nil })

        XCTAssertEqual(brief.summary, "本期主线是模型竞赛进入下半场，价格没有跟着能力一起降。")
        XCTAssertEqual(brief.displaySummary, brief.summary)
    }

    func testNullBodyNormalisesToNil() throws {
        let json = """
        {"id":"brf_null","channelId":"chn_1","title":"旧一期","summary":null,"body":null,
         "sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        XCTAssertNil(brief.body)
        XCTAssertFalse(brief.hasReadableBody)
        XCTAssertNil(brief.displaySummary)
    }

    func testMissingBodyFieldNormalisesToNil() throws {
        let json = """
        {"id":"brf_missing","channelId":"chn_1","title":"更旧的一期",
         "sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        XCTAssertNil(brief.body)
        XCTAssertFalse(brief.hasReadableBody)
        XCTAssertNil(brief.displaySummary)
    }

    func testEmptyParagraphsNormaliseToNilBody() throws {
        let json = """
        {"id":"brf_empty","channelId":"chn_1","title":"空正文","body":{"paragraphs":[]},
         "sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))

        // 空数组与 null 走同一条「无可读正文」路径。
        XCTAssertNil(dto.toDomain().body)
    }

    func testWhitespaceOnlyParagraphIsTreatedAsNoBody() throws {
        let json = """
        {"id":"brf_blank","channelId":"chn_1","title":"空白段","body":{"paragraphs":[
          {"segments":[{"type":"text","text":"   "}]}
        ]},"sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        XCTAssertFalse(brief.hasReadableBody)
    }

    // MARK: 片段解析与降级

    func testLinkWithoutURLDegradesToPlainText() throws {
        let json = """
        {"id":"brf_nourl","channelId":"chn_1","title":"坏链接","body":{"paragraphs":[
          {"segments":[{"type":"link","text":"原文","itemId":"itm_1"}]}
        ]},"sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let segment = try XCTUnwrap(dto.toDomain().body?.paragraphs.first?.segments.first)

        // 缺 url 的 link 不生成死链，降级为纯文字但内容保留。
        XCTAssertEqual(segment, .text("原文"))
        XCTAssertNil(segment.linkURL)
    }

    func testLinkWithInvalidURLDegradesToPlainText() throws {
        let json = """
        {"id":"brf_bad","channelId":"chn_1","title":"非法 URL","body":{"paragraphs":[
          {"segments":[{"type":"link","text":"原文","url":"not a url"}]}
        ]},"sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let segment = try XCTUnwrap(dto.toDomain().body?.paragraphs.first?.segments.first)

        XCTAssertEqual(segment, .text("原文"))
        XCTAssertNil(segment.linkURL)
    }

    func testUnknownSegmentTypeIsTreatedAsPlainText() throws {
        let json = """
        {"id":"brf_unknown","channelId":"chn_1","title":"未知类型","body":{"paragraphs":[
          {"segments":[{"type":"image","text":"图说","url":"https://e.test/a.png"}]}
        ]},"sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let segment = try XCTUnwrap(dto.toDomain().body?.paragraphs.first?.segments.first)

        // 未知类型不丢内容，按纯文字处理。
        XCTAssertEqual(segment, .text("图说"))
    }

    func testSegmentWithoutTextIsDropped() throws {
        let json = """
        {"id":"brf_notext","channelId":"chn_1","title":"空片段","body":{"paragraphs":[
          {"segments":[{"type":"text"},{"type":"text","text":"留下"}]}
        ]},"sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let segments = try XCTUnwrap(dto.toDomain().body?.paragraphs.first?.segments)

        XCTAssertEqual(segments, [.text("留下")])
    }

    // MARK: summary 归一化

    func testEmptySummaryIsTreatedAsAbsent() throws {
        let json = """
        {"id":"brf_es","channelId":"chn_1","title":"空描述","summary":"   ",
         "sections":[],"memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))

        XCTAssertNil(dto.toDomain().displaySummary)
    }

    func testSummaryIsKeptSeparateFromMemorySummary() throws {
        let json = """
        {"id":"brf_sep","channelId":"chn_1","title":"两段文字","summary":"给读者的一句话",
         "memorySummary":"给机器的一段记忆",
         "sections":[],"createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        // 两者不可混用：摘要给读者，记忆不展示。
        XCTAssertEqual(brief.displaySummary, "给读者的一句话")
        XCTAssertEqual(brief.memorySummary, "给机器的一段记忆")
        XCTAssertNotEqual(brief.displaySummary, brief.memorySummary)
    }

    // MARK: 读者端不渲染 sections

    func testSectionsStillDecodeButAreNotShownByTheReaderUI() throws {
        let json = """
        {"id":"brf_sec","channelId":"chn_1","title":"有分组也有正文",
         "body":{"paragraphs":[{"segments":[{"type":"text","text":"正文"}]}]},
         "sections":[{"title":"HN 首页","items":[{"title":"条目","itemId":null,"itemIds":["itm_1"]}]}],
         "memorySummary":"m","createdAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(BriefDTO.self, from: Data(json.utf8))
        let brief = dto.toDomain()

        // sections 仍被解析并保留在模型中（供后台与将来使用），
        // 但读者界面只用 body 渲染，见 BriefDetailView。
        XCTAssertEqual(brief.sections.count, 1)
        XCTAssertTrue(brief.hasReadableBody)
        XCTAssertEqual(brief.body?.paragraphs.first?.segments.first?.displayText, "正文")
    }
}
