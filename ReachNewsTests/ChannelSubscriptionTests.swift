import XCTest
@testable import ReachNews

// MARK: - 订阅模型
//
// 覆盖可写性判定、订阅 / 改色 / 取消 / fork 的请求形状与本地状态变化，
// 以及四个新错误码的归一化。全部用固定响应替身，不打真实网络。

@MainActor
final class ChannelSubscriptionTests: XCTestCase {

    // MARK: DTO 与判定

    func testChannelDTOFallsBackWhenSubscriptionFieldsMissing() throws {
        // 旧形状（无订阅字段）仍应可解码，且不把可编辑频道误判成只读。
        let json = """
        {"items":[{"id":"chn_old","name":"旧频道","prompt":"p","tone":"t","schedule":{},"enabled":true,
                   "connectorIds":[],"lastBriefAt":null,"kind":"channel",
                   "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"}],
         "nextCursor":null}
        """
        let envelope = try JSONDecoder().decode(
            PageEnvelope<ChannelDTO>.self,
            from: Data(json.utf8)
        )
        let channel = try XCTUnwrap(envelope.items.first?.toDomain())

        XCTAssertFalse(channel.published)
        XCTAssertEqual(channel.owner, .creator)
        XCTAssertFalse(channel.subscribed)
        XCTAssertNil(channel.subscriptionColor)
        XCTAssertNil(channel.subscriptionID)
        XCTAssertTrue(channel.canEdit)
    }

    func testChannelDTODecodesSubscriptionFields() throws {
        let data = try Fixture.data("channels")
        let envelope = try JSONDecoder().decode(PageEnvelope<ChannelDTO>.self, from: data)
        let channels = envelope.items.map { $0.toDomain() }

        let subscribed = try XCTUnwrap(channels.first { $0.owner == .subscriber && $0.subscribed })
        XCTAssertTrue(subscribed.published)
        XCTAssertEqual(subscribed.subscriptionColor, "#2E7D5B")
        XCTAssertNotNil(subscribed.subscriptionID)
        XCTAssertFalse(subscribed.canEdit)
        XCTAssertTrue(subscribed.canUnsubscribe)

        let discoverable = try XCTUnwrap(channels.first { $0.canSubscribe })
        XCTAssertTrue(discoverable.published)
        XCTAssertFalse(discoverable.subscribed)
    }

    func testSubscriptionColorIgnoresEmptyString() throws {
        let json = """
        {"id":"chn_s","name":"订阅频道","prompt":"","tone":"","schedule":{},"enabled":true,
         "connectorIds":[],"lastBriefAt":null,"kind":"channel","published":true,
         "owner":"subscriber","subscribed":true,"subscriptionColor":"",
         "subscriptionId":"sub_1",
         "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(ChannelDTO.self, from: Data(json.utf8))
        let channel = dto.toDomain()

        XCTAssertEqual(channel.subscriptionColor, "")
        // 空字符串按「未设置」处理：展示时回退到本地色板 / 按 id 稳定色。
        XCTAssertNil(channel.effectiveSubscriptionColor)
        let colors = ChannelColorStore(storage: InMemoryChannelColors())
        let index = colors.displayIndex(for: channel)
        XCTAssertEqual(index, ChannelTint.fallbackIndex(for: channel.id))
    }

    func testSingleChannelKeepsOwnerFromServer() throws {
        let json = """
        {"id":"chn_own","name":"我的频道","prompt":"","tone":"","schedule":{},"enabled":true,
         "connectorIds":[],"lastBriefAt":null,"kind":"channel","published":false,
         "owner":"creator","subscribed":false,"subscriptionColor":null,"subscriptionId":null,
         "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"}
        """
        let dto = try JSONDecoder().decode(ChannelDTO.self, from: Data(json.utf8))
        let channel = dto.toDomain()

        XCTAssertEqual(channel.owner, .creator)
        XCTAssertTrue(channel.canEdit)
        XCTAssertFalse(channel.published)
        XCTAssertNil(channel.subscriptionColor)
    }

    // MARK: 列表分段

    func testLoadSplitsChannelsByOwner() async throws {
        let transport = StubTransport(handler: { request in
            let isDiscover = request.url?.query?.contains("discover=1") ?? false
            return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))

        await store.load()

        XCTAssertEqual(store.myChannels.map(\.id), ["chn_mine"])
        XCTAssertEqual(store.subscribedChannels.map(\.id), ["chn_sub"])
        XCTAssertEqual(store.discoverableChannels.map(\.id), ["chn_public_other"])
        XCTAssertEqual(store.channels.count, 2)
    }

    func testLoadRequestsDefaultAndDiscoverSeparately() async throws {
        let transport = StubTransport(handler: { request in
            let isDiscover = request.url?.query?.contains("discover=1") ?? false
            return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))

        await store.load()

        let discoverRequests = transport.recorded.filter {
            $0.url.query?.contains("discover=1") ?? false
        }
        let defaultRequests = transport.recorded.filter {
            !($0.url.query?.contains("discover=1") ?? false)
        }
        XCTAssertEqual(discoverRequests.count, 1)
        XCTAssertEqual(defaultRequests.count, 1)
    }

    func testDiscoverFailureDoesNotClearDefaultList() async throws {
        let transport = StubTransport(handler: { request in
            if request.url?.query?.contains("discover=1") ?? false {
                return (500, Data(#"{"error":{"code":"internal_error","message":"boom"}}"#.utf8))
            }
            return (200, Data(Self.defaultPayload().utf8))
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))

        await store.load()

        XCTAssertEqual(store.myChannels.count, 1)
        XCTAssertEqual(store.subscribedChannels.count, 1)
        XCTAssertNil(store.error)
        XCTAssertNotNil(store.discoverError)
    }

    // MARK: 订阅动作

    func testSubscribeMovesChannelToSubscribedSegment() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_public_other/subscribe"):
                return (201, Data(Self.subscriptionJSON().utf8))
            case ("GET", "/api/v1/channels/chn_public_other"):
                return (200, Data(Self.subscribedChannelJSON(id: "chn_public_other").utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()
        XCTAssertEqual(store.discoverableChannels.count, 1)

        let subscribed = await store.subscribe("chn_public_other", colorIndex: 1)

        XCTAssertNotNil(subscribed)
        XCTAssertTrue(store.discoverableChannels.isEmpty)
        XCTAssertEqual(Set(store.subscribedChannels.map(\.id)), ["chn_sub", "chn_public_other"])
    }

    func testSubscribeSendsPaletteColorValue() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_public_other/subscribe"):
                return (201, Data(Self.subscriptionJSON().utf8))
            case ("GET", "/api/v1/channels/chn_public_other"):
                return (200, Data(Self.subscribedChannelJSON(id: "chn_public_other").utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        _ = await store.subscribe("chn_public_other", colorIndex: 3)

        let request = try XCTUnwrap(
            transport.recorded.first { $0.method == "POST" }
        )
        let body = try XCTUnwrap(request.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json.keys.sorted(), ["color"])
        XCTAssertEqual(json["color"] as? String, ChannelTint.paletteColorValue(at: 3))
    }

    func testSubscribeOwnChannelSurfacesOwnChannelError() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_mine/subscribe"):
                return (409, Data(#"{"error":{"code":"own_channel","message":"自己的频道"}}"#.utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        let result = await store.subscribe("chn_mine", colorIndex: 0)

        XCTAssertNil(result)
        XCTAssertEqual(store.discoverError, .ownChannel("自己的频道"))
        XCTAssertFalse(store.discoverableChannels.contains { $0.id == "chn_mine" })
    }

    func testSubscribeUnpublishedChannelSurfacesNotPublishedError() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_public_other/subscribe"):
                return (403, Data(#"{"error":{"code":"not_published","message":"未公开"}}"#.utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        let result = await store.subscribe("chn_public_other", colorIndex: 0)

        XCTAssertNil(result)
        XCTAssertEqual(store.discoverError, .notPublished("未公开"))
    }

    func testRepeatedSubscribeIsIdempotent() async throws {
        // 服务端重复订阅返回 200 与同一条记录；客户端不产生重复卡片。
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_public_other/subscribe"):
                return (200, Data(Self.subscriptionJSON().utf8))
            case ("GET", "/api/v1/channels/chn_public_other"):
                return (200, Data(Self.subscribedChannelJSON(id: "chn_public_other").utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        _ = await store.subscribe("chn_public_other", colorIndex: 1)
        _ = await store.subscribe("chn_public_other", colorIndex: 1)

        XCTAssertEqual(store.subscribedChannels.filter { $0.id == "chn_public_other" }.count, 1)
    }

    // MARK: 改订阅颜色

    func testUpdateSubscriptionColorUsesPatchAndRefreshesChannel() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("PATCH", "/api/v1/channels/chn_sub/subscribe"):
                return (200, Data(Self.subscribedChannelJSON(id: "chn_sub", color: "#B05A2A").utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        let updated = await store.updateSubscriptionColor("chn_sub", colorIndex: 2)

        XCTAssertEqual(updated?.subscriptionColor, "#B05A2A")
        XCTAssertEqual(store.subscribedChannels.first?.subscriptionColor, "#B05A2A")
        let request = try XCTUnwrap(transport.recorded.first { $0.method == "PATCH" })
        let body = try XCTUnwrap(request.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json.keys.sorted(), ["color"])
    }

    // MARK: 取消订阅

    func testUnsubscribeRemovesChannelAndReloadsDiscoverable() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("DELETE", "/api/v1/channels/chn_sub/subscribe"):
                return (200, Data(#"{"channelId":"chn_sub","subscribed":false}"#.utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()
        XCTAssertEqual(store.subscribedChannels.count, 1)

        let removed = await store.unsubscribe("chn_sub")

        XCTAssertTrue(removed)
        XCTAssertTrue(store.subscribedChannels.isEmpty)
        XCTAssertNil(store.channel(id: "chn_sub"))
    }

    func testUnsubscribeTreatsNotFoundAsAlreadyRemoved() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("DELETE", "/api/v1/channels/chn_sub/subscribe"):
                return (404, Data(#"{"error":{"code":"not_found","message":"Subscription not found"}}"#.utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        let removed = await store.unsubscribe("chn_sub")

        XCTAssertTrue(removed)
        XCTAssertTrue(store.subscribedChannels.isEmpty)
    }

    // MARK: fork

    func testForkAddsOwnChannelAndDropsSubscription() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_sub/fork"):
                return (201, Data(Self.forkedChannelJSON().utf8))
            case ("GET", _):
                let isDiscover = request.url?.query?.contains("discover=1") ?? false
                return (200, Data((isDiscover ? Self.discoverPayload() : Self.defaultPayload()).utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        let created = await store.fork("chn_sub")

        XCTAssertEqual(created?.id, "chn_forked")
        XCTAssertTrue(created?.owner.isCreator ?? false)
        XCTAssertFalse(created?.published ?? true)
        XCTAssertEqual(store.myChannels.first?.id, "chn_forked")
        XCTAssertTrue(store.subscribedChannels.isEmpty)
        XCTAssertNil(store.channel(id: "chn_sub"))
    }

    func testForkSendsForkMethodAndPath() async throws {
        let transport = StubTransport(handler: { request in
            switch (request.httpMethod, request.url?.path) {
            case ("POST", "/api/v1/channels/chn_sub/fork"):
                return (201, Data(Self.forkedChannelJSON().utf8))
            default:
                return (200, Data("{}".utf8))
            }
        })
        let store = ChannelStore(client: TestClient.make(transport: transport))

        _ = await store.fork("chn_sub")

        let request = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.path, "/api/v1/channels/chn_sub/fork")
    }

    // MARK: 错误归一化

    func testSubscriptionErrorCodesAreDistinct() {
        XCTAssertEqual(APIErrorCode.parse("presets_removed"), .presetsRemoved)
        XCTAssertEqual(APIErrorCode.parse("not_published"), .notPublished)
        XCTAssertEqual(APIErrorCode.parse("own_channel"), .ownChannel)
        XCTAssertEqual(APIErrorCode.parse("subscriber_read_only"), .subscriberReadOnly)
        // 旧接口停用不能被当成普通 404。
        XCTAssertNotEqual(APIErrorCode.parse("presets_removed"), .notFound)
        XCTAssertEqual(APIErrorCode.parse("still-unknown"), .unknown("still-unknown"))
    }

    func testSubscriptionErrorMessagesMapToLocalizedKeys() {
        XCTAssertEqual(APIError.ownChannel("x").messageKey, "error.ownChannel")
        XCTAssertEqual(APIError.notPublished("x").messageKey, "error.notPublished")
        XCTAssertEqual(APIError.subscriberReadOnly("x").messageKey, "error.subscriberReadOnly")
        XCTAssertEqual(APIError.removed("x").messageKey, "error.presetsRemoved")
        // 归一化后 detailText 保留服务端原文，供提示补充细节。
        XCTAssertEqual(APIError.ownChannel("自己的频道").detailText, "自己的频道")
    }

    func testEnvelopeMapsNewCodesToAPIError() throws {
        let cases: [(String, APIError)] = [
            ("presets_removed", .removed("m")),
            ("not_published", .notPublished("m")),
            ("own_channel", .ownChannel("m")),
            ("subscriber_read_only", .subscriberReadOnly("m"))
        ]
        for (code, expected) in cases {
            let json = #"{"error":{"code":"\#(code)","message":"m"}}"#
            let envelope = try JSONDecoder().decode(ErrorEnvelope.self, from: Data(json.utf8))
            XCTAssertEqual(envelope.normalized, expected, "code \(code)")
        }
    }

    // MARK: 日报流随订阅关系变化

    @MainActor
    func testForgetChannelClearsBriefsAndFilter() async throws {
        // 取消订阅后服务端立即隐藏该频道；本地日报流与筛选选中项也要同步失效。
        let transport = StubTransport(handler: { request in
            if request.url?.path == "/api/v1/briefs" {
                return (200, Data(Self.briefsPayload().utf8))
            }
            if request.url?.path == "/api/v1/cursor" {
                return (200, Data(#"{"briefs":[],"channels":[],"lastSeenAt":null}"#.utf8))
            }
            return (200, Data(Self.defaultPayload().utf8))
        })
        let preferences = InMemoryPreferences()
        let feed = BriefFeedStore(client: TestClient.make(transport: transport), preferences: preferences)
        await feed.loadFirstPage()
        XCTAssertTrue(feed.briefs.contains { $0.channelID == "chn_sub" })

        feed.filter.channelIDs.insert("chn_sub")
        feed.forgetChannel("chn_sub")

        XCTAssertFalse(feed.briefs.contains { $0.channelID == "chn_sub" })
        XCTAssertNil(feed.channel(for: "chn_sub"))
        XCTAssertFalse(feed.filter.channelIDs.contains("chn_sub"))
    }

    // MARK: 我的频道仍然可编辑

    func testPrivateOwnChannelRemainsEditable() async throws {
        let transport = StubTransport(json: Self.defaultPayload())
        let store = ChannelStore(client: TestClient.make(transport: transport))
        await store.load()

        let mine = try XCTUnwrap(store.myChannels.first)
        XCTAssertFalse(mine.published)
        XCTAssertTrue(mine.canEdit)
        XCTAssertNotNil(store.channel(id: mine.id))
    }

    // MARK: 固定样本

    nonisolated private static func defaultPayload() -> String {
        """
        {"items":[
          {"id":"chn_mine","name":"我的频道","prompt":"p","tone":"t","schedule":{"mon":["08:00"]},
           "enabled":true,"connectorIds":[],"lastBriefAt":null,"kind":"channel","published":false,
           "owner":"creator","subscribed":false,"subscriptionColor":null,"subscriptionId":null,
           "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"},
          {"id":"chn_sub","name":"安全观察","prompt":"p","tone":"t","schedule":{},
           "enabled":true,"connectorIds":[],"lastBriefAt":null,"kind":"channel","published":true,
           "owner":"subscriber","subscribed":true,"subscriptionColor":"#2E7D5B","subscriptionId":"sub_1",
           "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"}
        ],"nextCursor":null}
        """
    }

    nonisolated private static func discoverPayload() -> String {
        """
        {"items":[
          {"id":"chn_public_other","name":"公开市场速览","prompt":"p","tone":"t","schedule":{},
           "enabled":true,"connectorIds":[],"lastBriefAt":null,"kind":"channel","published":true,
           "owner":"subscriber","subscribed":false,"subscriptionColor":null,"subscriptionId":null,
           "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-20T02:01:50.774Z"}
        ],"nextCursor":null}
        """
    }

    nonisolated private static func subscriptionJSON() -> String {
        """
        {"id":"sub_2","channelId":"chn_public_other","color":"#2E7D5B",
         "createdAt":"2026-11-21T01:00:00.000Z","subscribed":true}
        """
    }

    nonisolated private static func subscribedChannelJSON(id: String, color: String = "#2E7D5B") -> String {
        """
        {"id":"\(id)","name":"公开市场速览","prompt":"p","tone":"t","schedule":{},"enabled":true,
         "connectorIds":[],"lastBriefAt":null,"kind":"channel","published":true,
         "owner":"subscriber","subscribed":true,"subscriptionColor":"\(color)",
         "subscriptionId":"sub_2",
         "createdAt":"2026-11-20T02:01:50.774Z","updatedAt":"2026-11-21T01:00:00.000Z"}
        """
    }

    nonisolated private static func briefsPayload() -> String {
        """
        {"items":[
          {"id":"brf_sub","channelId":"chn_sub","title":"安全周报","sections":[],"memorySummary":"m",
           "createdAt":"2026-11-21T01:00:00.000Z"},
          {"id":"brf_mine","channelId":"chn_mine","title":"我的周报","sections":[],"memorySummary":"m",
           "createdAt":"2026-11-21T00:00:00.000Z"}
        ],"nextCursor":null}
        """
    }

    nonisolated private static func forkedChannelJSON() -> String {
        """
        {"id":"chn_forked","name":"安全观察","prompt":"p","tone":"t","schedule":{},"enabled":true,
         "connectorIds":[],"lastBriefAt":null,"kind":"channel","published":false,
         "owner":"creator","subscribed":false,"subscriptionColor":null,"subscriptionId":null,
         "createdAt":"2026-11-21T01:00:00.000Z","updatedAt":"2026-11-21T01:00:00.000Z"}
        """
    }
}
