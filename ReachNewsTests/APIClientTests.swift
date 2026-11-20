import XCTest
@testable import ReachNews

// MARK: - 网络层行为

final class APIClientTests: XCTestCase {
    func testAuthorizationHeaderIsAttached() async throws {
        let transport = StubTransport(json: #"{"ok":true,"service":"reach-news","time":"2026-11-20T02:01:50.774Z"}"#)
        let client = TestClient.make(transport: transport, token: "secret-token")

        _ = try await client.channels(limit: 1)

        XCTAssertEqual(transport.recorded.first?.authorization, "Bearer secret-token")
    }

    func testHealthEndpointSkipsAuthorization() async throws {
        let transport = StubTransport(json: #"{"ok":true,"service":"reach-news","time":"2026-11-20T02:01:50.774Z"}"#)
        let client = TestClient.make(transport: transport)

        let health = try await client.health()

        XCTAssertTrue(health.ok)
        XCTAssertNil(transport.recorded.first?.authorization)
        XCTAssertEqual(transport.recorded.first?.url.path, "/health")
    }

    func testMissingTokenFailsWithoutRequest() async {
        let transport = StubTransport(json: "{}")
        let client = TestClient.make(transport: transport, token: nil)

        do {
            _ = try await client.channels()
            XCTFail("Expected unauthorized")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        // 没有凭证时不发请求。
        XCTAssertTrue(transport.recorded.isEmpty)
    }

    func testErrorEnvelopeIsNormalized() async {
        let transport = StubTransport(
            json: #"{"error":{"code":"invalid_input","message":"limit must be a positive integer"}}"#,
            status: 400
        )
        let client = TestClient.make(transport: transport)

        do {
            _ = try await client.channels(limit: 20)
            XCTFail("Expected failure")
        } catch let error as APIError {
            XCTAssertEqual(error, .invalidInput("limit must be a positive integer"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnauthorizedStatusWithoutEnvelope() async {
        let transport = StubTransport(json: "", status: 401)
        let client = TestClient.make(transport: transport)

        do {
            _ = try await client.channels()
            XCTFail("Expected unauthorized")
        } catch let error as APIError {
            XCTAssertEqual(error, .unauthorized)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testNotFoundStatusWithoutEnvelope() async {
        let transport = StubTransport(json: "", status: 404)
        let client = TestClient.make(transport: transport)

        do {
            _ = try await client.brief(id: "brf_missing")
            XCTFail("Expected notFound")
        } catch let error as APIError {
            XCTAssertEqual(error, .notFound)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testTransportFailureBecomesOffline() async {
        let transport = StubTransport { _ in
            throw URLError(.notConnectedToInternet)
        }
        let client = TestClient.make(transport: transport)

        do {
            _ = try await client.channels()
            XCTFail("Expected offline")
        } catch let error as APIError {
            XCTAssertTrue(error.isOffline)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUndecodableBodyIsReported() async {
        let transport = StubTransport(json: "not json")
        let client = TestClient.make(transport: transport)

        do {
            _ = try await client.channels()
            XCTFail("Expected decoding failure")
        } catch let error as APIError {
            XCTAssertEqual(error, .decodingFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAskPostsMessageAndReturnsAnswer() async throws {
        let transport = StubTransport(
            json: #"{"message":"这条哪来的","answer":"已基于归档摘要记录问题"}"#,
            status: 201
        )
        let client = TestClient.make(transport: transport)

        let turn = try await client.ask(briefID: "brf_1", message: "这条哪来的")

        XCTAssertEqual(turn.role, .assistant)
        XCTAssertEqual(turn.message, "已基于归档摘要记录问题")

        let request = try XCTUnwrap(transport.recorded.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.url.path, "/api/v1/briefs/brf_1/ask")
        let body = try XCTUnwrap(request.body)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(json["message"], "这条哪来的")
    }

    func testPaginationParamsAreSentAsContractRequires() async throws {
        let transport = StubTransport(json: #"{"items":[],"nextCursor":null}"#)
        let client = TestClient.make(transport: transport)

        _ = try await client.channels(cursor: "20", limit: 40)

        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(transport.recorded.first?.url), resolvingAgainstBaseURL: false))
        let items = try XCTUnwrap(components.queryItems)
        XCTAssertEqual(items.first { $0.name == "limit" }?.value, "40")
        XCTAssertEqual(items.first { $0.name == "cursor" }?.value, "20")
    }

    func testNegativeCursorFromServerIsDiscarded() async throws {
        // 服务端在负 cursor 下可能返回非空 nextCursor，客户端不缓存这种值。
        let transport = StubTransport(json: #"{"items":[],"nextCursor":"-5"}"#)
        let client = TestClient.make(transport: transport)

        let page = try await client.channels(cursor: nil, limit: 20)

        XCTAssertNil(page.nextCursor)
    }

    func testWithBaseURLProducesIndependentClient() async throws {
        let transport = StubTransport(json: #"{"ok":true,"service":"reach-news","time":null}"#)
        let client = TestClient.make(transport: transport)
        let alternate = client.withBaseURL(URL(string: "http://localhost:5100")!)

        _ = try await alternate.health()

        XCTAssertEqual(transport.recorded.first?.url.host(), "localhost")
        XCTAssertEqual(client.baseURL.host(), BaseURLDefaults.url.host())
    }
}

// MARK: - 会话双验证

final class SessionStoreTests: XCTestCase {
    @MainActor
    func testConnectRequiresBothHealthAndChannelAccess() async {
        let credentials = InMemoryCredentials()
        let preferences = InMemoryPreferences()
        let transport = StubTransport { request in
            if request.url?.path == "/health" {
                return (200, Data(#"{"ok":true,"service":"reach-news","time":"2026-11-20T02:01:50.774Z"}"#.utf8))
            }
            return (200, Data(#"{"items":[],"nextCursor":null}"#.utf8))
        }
        let client = TestClient.make(transport: transport, token: nil)
        let session = SessionStore(
            credentials: credentials,
            preferences: preferences,
            makeClient: { _ in client }
        )
        session.tokenInput = "new-token"

        let ok = await session.connect()

        XCTAssertTrue(ok)
        XCTAssertEqual(credentials.storedToken, "new-token")
        XCTAssertTrue(session.isConnected)
        XCTAssertEqual(transport.recorded.map(\.url.path), ["/health", "/api/v1/channels"])
    }

    @MainActor
    func testInvalidTokenDoesNotPersistCredential() async {
        let credentials = InMemoryCredentials()
        let preferences = InMemoryPreferences()
        let transport = StubTransport { request in
            if request.url?.path == "/health" {
                return (200, Data(#"{"ok":true,"service":"reach-news","time":null}"#.utf8))
            }
            return (401, Data(#"{"error":{"code":"unauthorized","message":"Bearer token required"}}"#.utf8))
        }
        let client = TestClient.make(transport: transport, token: nil)
        let session = SessionStore(
            credentials: credentials,
            preferences: preferences,
            makeClient: { _ in client }
        )
        session.tokenInput = "bad-token"

        let ok = await session.connect()

        XCTAssertFalse(ok)
        XCTAssertNil(credentials.storedToken)
        XCTAssertFalse(session.isConnected)
    }

    @MainActor
    func testUnreachableServiceReportsOffline() async {
        let credentials = InMemoryCredentials()
        let preferences = InMemoryPreferences()
        let transport = StubTransport { _ in throw URLError(.cannotConnectToHost) }
        let client = TestClient.make(transport: transport, token: nil)
        let session = SessionStore(
            credentials: credentials,
            preferences: preferences,
            makeClient: { _ in client }
        )
        session.tokenInput = "token"

        let ok = await session.connect()

        XCTAssertFalse(ok)
        if case .failed(let error) = session.state {
            XCTAssertTrue(error.isOffline || error == .offline)
        } else {
            XCTFail("Expected failed state")
        }
        XCTAssertNil(credentials.storedToken)
    }

    @MainActor
    func testInvalidBaseURLIsRejectedBeforeRequest() async {
        let credentials = InMemoryCredentials()
        let preferences = InMemoryPreferences()
        let transport = StubTransport(json: "{}")
        let client = TestClient.make(transport: transport, token: nil)
        let session = SessionStore(
            credentials: credentials,
            preferences: preferences,
            makeClient: { _ in client }
        )
        session.baseURLString = "ftp://nope"
        session.tokenInput = "token"

        let ok = await session.connect()

        XCTAssertFalse(ok)
        XCTAssertTrue(transport.recorded.isEmpty)
    }

    @MainActor
    func testForgetCredentialsClearsStore() {
        let credentials = InMemoryCredentials(token: "existing")
        let preferences = InMemoryPreferences()
        let client = TestClient.make(transport: StubTransport(json: "{}"))
        let session = SessionStore(
            credentials: credentials,
            preferences: preferences,
            makeClient: { _ in client }
        )
        XCTAssertTrue(session.hasStoredToken)

        session.forgetCredentials()

        XCTAssertNil(credentials.storedToken)
        XCTAssertFalse(session.hasStoredToken)
        XCTAssertFalse(session.isConnected)
    }
}
