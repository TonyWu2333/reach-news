import Foundation

// MARK: - 传输协议
//
// APIClient 只依赖这个协议，测试可注入固定响应而不打网络。

protocol HTTPTransporting {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

struct URLSessionTransport: HTTPTransporting {
    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport("unexpected-response")
            }
            return (data, http)
        } catch let error as APIError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain {
                switch nsError.code {
                case NSURLErrorNotConnectedToInternet,
                     NSURLErrorNetworkConnectionLost,
                     NSURLErrorCannotConnectToHost,
                     NSURLErrorCannotFindHost,
                     NSURLErrorTimedOut,
                     NSURLErrorDataNotAllowed:
                    throw APIError.offline
                default:
                    throw APIError.transport(nsError.localizedDescription)
                }
            }
            throw APIError.transport(error.localizedDescription)
        }
    }
}

// MARK: - 端点

enum Endpoint {
    case health
    case channels(cursor: String?, limit: Int)
    case channel(id: String)
    case briefs(channelID: String, cursor: String?, limit: Int)
    case brief(id: String)
    case material(briefID: String, materialID: String)
    case runs(channelID: String, cursor: String?, limit: Int)
    case run(id: String)
    case askHistory(briefID: String, cursor: String?, limit: Int)
    case ask(briefID: String)
    case cursor(since: Date?)

    var path: String {
        switch self {
        case .health:
            return "/health"
        case .channels:
            return "/api/v1/channels"
        case .channel(let id):
            return "/api/v1/channels/\(id)"
        case .briefs(let channelID, _, _):
            return "/api/v1/channels/\(channelID)/briefs"
        case .brief(let id):
            return "/api/v1/briefs/\(id)"
        case .material(let briefID, let materialID):
            return "/api/v1/briefs/\(briefID)/items/\(materialID)"
        case .runs(let channelID, _, _):
            return "/api/v1/channels/\(channelID)/runs"
        case .run(let id):
            return "/api/v1/runs/\(id)"
        case .askHistory(let briefID, _, _):
            return "/api/v1/briefs/\(briefID)/ask"
        case .ask(let briefID):
            return "/api/v1/briefs/\(briefID)/ask"
        case .cursor:
            return "/api/v1/cursor"
        }
    }

    var queryItems: [URLQueryItem] {
        switch self {
        case .channels(let cursor, let limit),
             .askHistory(_, let cursor, let limit):
            return Pagination.queryItems(cursor: cursor, limit: limit)
        case .briefs(_, let cursor, let limit),
             .runs(_, let cursor, let limit):
            return Pagination.queryItems(cursor: cursor, limit: limit)
        case .cursor(let since):
            return [URLQueryItem(name: "since", value: PollingBaseline.sinceString(since))]
        case .health, .channel, .brief, .material, .run, .ask:
            return []
        }
    }

    var requiresAuthorization: Bool {
        if case .health = self { return false }
        return true
    }
}

// MARK: - API 客户端

final class APIClient {
    private let transport: HTTPTransporting
    private let credentials: CredentialProviding
    let baseURL: URL

    init(
        baseURL: URL,
        transport: HTTPTransporting = URLSessionTransport(),
        credentials: CredentialProviding
    ) {
        self.baseURL = baseURL
        self.transport = transport
        self.credentials = credentials
    }

    /// 复制成指向另一个基础地址的客户端；已有实例不变。
    func withBaseURL(_ url: URL) -> APIClient {
        APIClient(baseURL: url, transport: transport, credentials: credentials)
    }

    // MARK: 端点调用

    func health() async throws -> HealthDTO {
        try await get(Endpoint.health)
    }

    func channels(cursor: String? = nil, limit: Int = Pagination.defaultLimit) async throws -> Page<Channel> {
        let envelope: PageEnvelope<ChannelDTO> = try await get(Endpoint.channels(cursor: cursor, limit: limit))
        return Page(items: envelope.items.map { $0.toDomain() },
                    nextCursor: Pagination.sanitizedCursor(envelope.nextCursor))
    }

    func channel(id: String) async throws -> Channel {
        let dto: ChannelDTO = try await get(Endpoint.channel(id: id))
        return dto.toDomain()
    }

    func briefs(channelID: String, cursor: String? = nil, limit: Int = Pagination.defaultLimit) async throws -> Page<Brief> {
        let envelope: PageEnvelope<BriefDTO> = try await get(
            Endpoint.briefs(channelID: channelID, cursor: cursor, limit: limit)
        )
        return Page(items: envelope.items.map { $0.toDomain() },
                    nextCursor: Pagination.sanitizedCursor(envelope.nextCursor))
    }

    func brief(id: String) async throws -> Brief {
        let dto: BriefDTO = try await get(Endpoint.brief(id: id))
        return dto.toDomain()
    }

    func material(briefID: String, materialID: String) async throws -> Material {
        let dto: MaterialDTO = try await get(Endpoint.material(briefID: briefID, materialID: materialID))
        guard let material = dto.toDomain() else { throw APIError.decodingFailed }
        return material
    }

    func runs(channelID: String, cursor: String? = nil, limit: Int = Pagination.defaultLimit) async throws -> Page<Run> {
        let envelope: PageEnvelope<RunDTO> = try await get(
            Endpoint.runs(channelID: channelID, cursor: cursor, limit: limit)
        )
        return Page(items: envelope.items.map { $0.toDomain() },
                    nextCursor: Pagination.sanitizedCursor(envelope.nextCursor))
    }

    func run(id: String) async throws -> Run {
        let dto: RunDTO = try await get(Endpoint.run(id: id))
        return dto.toDomain()
    }

    func cursor(since: Date?) async throws -> CursorPayload {
        let dto: CursorDTO = try await get(Endpoint.cursor(since: since))
        return dto.toDomain()
    }

    func askHistory(briefID: String, cursor: String? = nil, limit: Int = Pagination.defaultLimit) async throws -> Page<AskTurn> {
        let envelope: PageEnvelope<AskTurnDTO> = try await get(
            Endpoint.askHistory(briefID: briefID, cursor: cursor, limit: limit)
        )
        return Page(items: envelope.items.map { $0.toDomain() },
                    nextCursor: Pagination.sanitizedCursor(envelope.nextCursor))
    }

    func ask(briefID: String, message: String) async throws -> AskTurn {
        let body = try JSONEncoder().encode(AskRequestBody(message: message))
        let dto: AskResponseDTO = try await send(Endpoint.ask(briefID: briefID), method: "POST", body: body)
        return AskTurn(
            id: UUID().uuidString,
            role: .assistant,
            message: dto.answer,
            createdAt: Date()
        )
    }

    func patchChannel(id: String, changes: ChannelChanges) async throws -> Channel {
        let body = try JSONEncoder().encode(ChannelPatchBody(changes: changes))
        let dto: ChannelDTO = try await send(Endpoint.channel(id: id), method: "PATCH", body: body)
        return dto.toDomain()
    }

    // MARK: 请求构造与响应处理

    private func get<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        try await send(endpoint, method: "GET", body: nil)
    }

    private func send<T: Decodable>(_ endpoint: Endpoint, method: String, body: Data?) async throws -> T {
        let request = try makeRequest(endpoint, method: method, body: body)
        let (data, response) = try await transport.send(request)

        guard (200..<300).contains(response.statusCode) else {
            if let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
                throw envelope.normalized
            }
            if response.statusCode == 401 { throw APIError.unauthorized }
            if response.statusCode == 404 { throw APIError.notFound }
            throw APIError.server("HTTP \(response.statusCode)")
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed
        }
    }

    private func makeRequest(_ endpoint: Endpoint, method: String, body: Data?) throws -> URLRequest {
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidConfiguration
        }
        components.path = endpoint.path
        if !endpoint.queryItems.isEmpty {
            components.queryItems = endpoint.queryItems
        }
        guard let url = components.url else { throw APIError.invalidConfiguration }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if endpoint.requiresAuthorization {
            guard let token = credentials.token(), !token.isEmpty else {
                throw APIError.unauthorized
            }
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }
}

// MARK: - 基础地址

enum BaseURLDefaults {
    static let host = "https://reachapi.niuma.art"

    static var url: URL {
        URL(string: host) ?? URL(fileURLWithPath: "/")
    }

    /// 接受用户输入的地址：补齐 scheme，去掉尾部斜杠；不接受空值与非 http(s)。
    static func parse(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://\(trimmed)"
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              url.host() != nil else {
            return nil
        }
        return url
    }
}
