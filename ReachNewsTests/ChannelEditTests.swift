import XCTest
@testable import ReachNews

// MARK: - 频道编辑

final class ChannelEditTests: XCTestCase {
    func testEmptyDraftProducesNoChanges() {
        let channel = makeChannel()
        let draft = ChannelDraft(channel: channel)
        let changes = draft.changes(against: channel)

        XCTAssertTrue(changes.isEmpty)
        XCTAssertTrue(changes.changedFieldNames.isEmpty)
    }

    func testOnlyChangedFieldsAreSubmitted() {
        let channel = makeChannel()
        var draft = ChannelDraft(channel: channel)
        draft.name = "新名字"
        draft.tone = "更克制"

        let changes = draft.changes(against: channel)

        XCTAssertFalse(changes.isEmpty)
        XCTAssertEqual(changes.name, "新名字")
        XCTAssertEqual(changes.tone, "更克制")
        // 未改动的字段不出现，因此不会被提交。
        XCTAssertNil(changes.prompt)
        XCTAssertNil(changes.schedule)
        XCTAssertNil(changes.enabled)
        XCTAssertEqual(changes.changedFieldNames, ["name", "tone"])
    }

    func testScheduleChangeIsDetected() {
        let channel = makeChannel()
        var draft = ChannelDraft(channel: channel)
        var schedule = draft.schedule
        schedule.addTime("18:00", to: Schedule.Weekday.all[0])
        draft.schedule = schedule

        let changes = draft.changes(against: channel)
        XCTAssertNotNil(changes.schedule)
        XCTAssertEqual(changes.changedFieldNames, ["schedule"])
    }

    func testPatchBodyOmitsUnchangedKeys() throws {
        let channel = makeChannel()
        var draft = ChannelDraft(channel: channel)
        draft.enabled = false

        let body = ChannelPatchBody(changes: draft.changes(against: channel))
        let data = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(json.keys.sorted(), ["enabled"])
        XCTAssertEqual(json["enabled"] as? Bool, false)
    }

    func testPatchBodyEncodesScheduleWithWeekdayKeys() throws {
        let channel = makeChannel()
        var draft = ChannelDraft(channel: channel)
        draft.schedule = Schedule(timesByWeekday: ["mon": ["08:00"], "fri": ["18:00"]])

        let body = ChannelPatchBody(changes: draft.changes(against: channel))
        let data = try JSONEncoder().encode(body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let schedule = try XCTUnwrap(json["schedule"] as? [String: [String]])

        // 只提交配置过的星期。
        XCTAssertEqual(schedule.keys.sorted(), ["fri", "mon"])
        XCTAssertEqual(schedule["mon"], ["08:00"])
        XCTAssertEqual(schedule["fri"], ["18:00"])
    }

    @MainActor
    func testBusyErrorIsRecognisedAsRunning() async {
        let channel = makeChannel()
        let transport = StubTransport(json: #"{"error":{"code":"busy","message":"Channel has a run in progress"}}"#, status: 409)
        let client = TestClient.make(transport: transport)
        let editor = ChannelEditor(channel: channel, client: client)
        editor.draft.name = "改过的名字"

        let result = await editor.save()

        XCTAssertNil(result)
        XCTAssertTrue(editor.isBlockedByRunning)
        // 409 之后已填内容必须保留。
        XCTAssertEqual(editor.draft.name, "改过的名字")
        XCTAssertFalse(editor.didSave)
    }

    @MainActor
    func testSaveSubmitsPatchToChannelEndpoint() async throws {
        let channel = makeChannel()
        // PATCH 返回单个频道对象：从 channels.json 取出第一项的原始 JSON。
        let responseBody = try firstChannelObjectJSON()
        let transport = StubTransport(handler: { request in
            XCTAssertEqual(request.httpMethod, "PATCH")
            XCTAssertEqual(request.url?.path, "/api/v1/channels/\(channel.id)")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
            return (200, responseBody)
        })
        let client = TestClient.make(transport: transport)
        let editor = ChannelEditor(channel: channel, client: client)
        editor.draft.enabled = false

        _ = await editor.save()

        let body = try XCTUnwrap(transport.recorded.first?.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json.keys.sorted(), ["enabled"])
    }

    // MARK: 辅助

    /// 从 channels.json 取出单个频道对象的原始 JSON（PATCH 的响应形状）。
    private func firstChannelObjectJSON() throws -> Data {
        let root = try JSONSerialization.jsonObject(with: try Fixture.data("channels")) as? [String: Any]
        let items = try XCTUnwrap(root?["items"] as? [[String: Any]])
        let first = try XCTUnwrap(items.first)
        return try JSONSerialization.data(withJSONObject: first)
    }

    private func makeChannel() -> Channel {
        Channel(
            id: "chn_test",
            name: "AI 前沿",
            prompt: "总结今天的进展",
            tone: "简洁中文",
            schedule: Schedule(timesByWeekday: ["mon": ["08:00"]]),
            enabled: true,
            connectorIDs: ["cnn_homepage"],
            lastBriefAt: nil,
            kind: .channel,
            createdAt: Date(timeIntervalSince1970: 0),
            updatedAt: Date(timeIntervalSince1970: 0)
        )
    }
}

// MARK: - 删除频道（A43 / A44）

final class ChannelDeleteTests: XCTestCase {
    private func makeStore(_ transport: StubTransport) -> ChannelStore {
        ChannelStore(client: TestClient.make(transport: transport))
    }

    @MainActor
    func testDeleteCallsDeleteEndpoint() async {
        let transport = StubTransport(json: #"{"id":"chn_1","deleted":true}"#)
        let store = makeStore(transport)

        let ok = await store.delete("chn_1")

        XCTAssertTrue(ok)
        let request = transport.recorded.first
        XCTAssertEqual(request?.method, "DELETE")
        XCTAssertEqual(request?.url.path, "/api/v1/channels/chn_1")
    }

    @MainActor
    func testDeleteRemovesChannelFromList() async {
        let channelsJSON = """
        {"items":[{"id":"chn_1","name":"A","prompt":"","tone":"","schedule":{},"enabled":true,
                   "connectorIds":[],"lastBriefAt":null,"kind":"channel",
                   "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"}],
         "nextCursor":null}
        """
        var callCount = 0
        let transport = StubTransport { request in
            callCount += 1
            if request.httpMethod == "DELETE" {
                return (200, Data(#"{"id":"chn_1","deleted":true}"#.utf8))
            }
            return (200, Data(channelsJSON.utf8))
        }
        let store = makeStore(transport)
        await store.load()
        XCTAssertEqual(store.channels.count, 1)

        _ = await store.delete("chn_1")

        XCTAssertTrue(store.channels.isEmpty)
    }

    @MainActor
    func testNotFoundIsTreatedAsAlreadyDeleted() async {
        // 别人的频道或已删除的频道都返回 404：按已删除处理，不报错。
        let transport = StubTransport(
            json: #"{"error":{"code":"not_found","message":"Channel not found"}}"#,
            status: 404
        )
        let store = makeStore(transport)

        let ok = await store.delete("chn_missing")

        XCTAssertTrue(ok)
        XCTAssertNil(store.createError)
    }

    @MainActor
    func testBusyDoesNotDelete() async {
        // 有运行在跑返回 409：不删除，并把原因留给界面提示。
        let transport = StubTransport(
            json: #"{"error":{"code":"busy","message":"Channel is not idle"}}"#,
            status: 409
        )
        let store = makeStore(transport)

        let ok = await store.delete("chn_busy")

        XCTAssertFalse(ok)
        XCTAssertEqual(store.createError, .busy("Channel is not idle"))
    }

    @MainActor
    func testDeleteSendsAuthorization() async {
        let transport = StubTransport(json: #"{"id":"chn_1","deleted":true}"#)
        let store = makeStore(transport)

        _ = await store.delete("chn_1")

        XCTAssertEqual(transport.recorded.first?.authorization, "Bearer test-token")
    }
}
