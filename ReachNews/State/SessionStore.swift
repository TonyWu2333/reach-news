import Foundation
import Observation

// MARK: - 会话（鉴权与连接）
//
// 双验证：/health 确认服务可达，/api/v1/channels 确认 token 有效。
// 两者都通过才写入 Keychain 并覆盖旧凭证。

@MainActor
@Observable
final class SessionStore {
    enum State: Equatable {
        case unconfigured
        case connecting
        case connected
        case failed(APIError)
    }

    private(set) var state: State = .unconfigured
    private(set) var hasStoredToken: Bool
    private(set) var serviceTime: Date?

    var baseURLString: String
    var tokenInput: String = ""

    @ObservationIgnored private let credentials: CredentialProviding
    @ObservationIgnored private let preferences: PreferencesStoring
    @ObservationIgnored private let makeClient: (URL) -> APIClient

    init(
        credentials: CredentialProviding,
        preferences: PreferencesStoring,
        makeClient: @escaping (URL) -> APIClient
    ) {
        self.credentials = credentials
        self.preferences = preferences
        self.makeClient = makeClient
        self.baseURLString = preferences.baseURLString
        self.hasStoredToken = credentials.token()?.isEmpty == false
        if hasStoredToken {
            state = .connected
        }
    }

    var isConnected: Bool {
        if case .connected = state { return true }
        return false
    }

    var isConnecting: Bool {
        if case .connecting = state { return true }
        return false
    }

    /// 当前生效的基础地址；地址不合法时回落默认值。
    var resolvedBaseURL: URL {
        BaseURLDefaults.parse(baseURLString) ?? BaseURLDefaults.url
    }

    /// 已保存的凭证别名，用于「我的」页展示，不暴露 token 本身。
    var credentialSummaryKey: String {
        hasStoredToken ? "connection.credential.stored" : "connection.credential.missing"
    }

    /// 首次连接或更换凭证：执行双验证，通过后才落库。
    /// 未经验证的凭证绝不写入 Keychain，也不覆盖已有凭证。
    func connect(tokenOverride: String? = nil) async -> Bool {
        guard let url = BaseURLDefaults.parse(baseURLString) else {
            state = .failed(.invalidConfiguration)
            return false
        }

        let candidate = (tokenOverride ?? tokenInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let existing = credentials.token() ?? ""
        let effectiveToken = candidate.isEmpty ? existing : candidate

        guard !effectiveToken.isEmpty else {
            state = .failed(.unauthorized)
            return false
        }

        state = .connecting

        // 用候选凭证临时构造客户端，验证通过后才真正落库。
        let probeCredentials = TemporaryCredentials(token: effectiveToken)
        let client = makeClient(url).withCredentials(probeCredentials)

        do {
            let health = try await client.health()
            guard health.ok else {
                state = .failed(.server("health-not-ok"))
                return false
            }
            serviceTime = JSONDate.parse(health.time)

            _ = try await client.channels(limit: 1)

            // 两项都通过：此刻才写入 Keychain 并覆盖旧凭证。
            try credentials.store(token: effectiveToken)
            preferences.baseURLString = url.absoluteString
            baseURLString = url.absoluteString
            tokenInput = ""
            hasStoredToken = true
            state = .connected
            return true
        } catch let error as APIError {
            state = .failed(error)
            return false
        } catch {
            state = .failed(.transport(error.localizedDescription))
            return false
        }
    }

    /// 启动时若已有凭证，只验证而不改动存储。
    func validateStoredCredentials() async {
        guard hasStoredToken else {
            state = .unconfigured
            return
        }
        let client = makeClient(resolvedBaseURL)
        do {
            let health = try await client.health()
            guard health.ok else {
                state = .failed(.server("health-not-ok"))
                return
            }
            serviceTime = JSONDate.parse(health.time)
            _ = try await client.channels(limit: 1)
            state = .connected
        } catch let error as APIError {
            state = error == .unauthorized ? .failed(.unauthorized) : .failed(error)
        } catch {
            state = .failed(.transport(error.localizedDescription))
        }
    }

    /// 凭证失效（401）时回到连接页。
    func handleUnauthorized() {
        state = .failed(.unauthorized)
    }

    func forgetCredentials() {
        credentials.clearToken()
        hasStoredToken = false
        tokenInput = ""
        state = .unconfigured
    }

    func resetError() {
        if case .failed = state {
            state = hasStoredToken ? .connected : .unconfigured
        }
    }
}

// MARK: - 错误文案
//
// 把归一化错误转成可展示的本地化键，避免视图里散落 switch。

extension APIError {
    var messageKey: String {
        switch self {
        case .offline: return "error.offline"
        case .transport: return "error.transport"
        case .unauthorized: return "error.unauthorized"
        case .notFound: return "error.notFound"
        case .invalidInput: return "error.invalidInput"
        case .busy: return "error.busy"
        case .badRequest: return "error.badRequest"
        case .server: return "error.server"
        case .decodingFailed: return "error.decoding"
        case .invalidConfiguration: return "error.configuration"
        }
    }

    /// 服务端给出的原始说明，用于在通用文案下补充细节。
    var detailText: String? {
        switch self {
        case .invalidInput(let message), .busy(let message), .badRequest(let message), .server(let message):
            return message.isEmpty ? nil : message
        case .transport(let message):
            return message.isEmpty ? nil : message
        case .offline, .unauthorized, .notFound, .decodingFailed, .invalidConfiguration:
            return nil
        }
    }
}
