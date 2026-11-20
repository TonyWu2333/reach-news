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
    func connect(tokenOverride: String? = nil) async -> Bool {
        let rawURL = baseURLString
        guard let url = BaseURLDefaults.parse(rawURL) else {
            state = .failed(.invalidConfiguration)
            return false
        }
        let candidateToken = (tokenOverride ?? tokenInput).trimmingCharacters(in: .whitespacesAndNewlines)
        let existingToken = credentials.token() ?? ""

        // 更换凭证时必须有新 token；首次连接时用输入值。
        let effectiveToken = candidateToken.isEmpty ? existingToken : candidateToken

        state = .connecting
        let client = makeClient(url)

        do {
            let health = try await client.health()
            guard health.ok else {
                state = .failed(.server("health-not-ok"))
                return false
            }
            serviceTime = JSONDate.parse(health.time)

            // 校验 token 是否可读频道。health 之后才验证，便于区分「地址错」与「凭证错」。
            guard !effectiveToken.isEmpty else {
                state = .failed(.unauthorized)
                return false
            }
            do {
                try credentials.store(token: effectiveToken)
            } catch {
                state = .failed(.invalidConfiguration)
                return false
            }
            _ = try await client.channels(limit: 1)

            preferences.baseURLString = url.absoluteString
            baseURLString = url.absoluteString
            tokenInput = ""
            hasStoredToken = true
            state = .connected
            return true
        } catch let error as APIError {
            // 校验失败时不留下未经验证的凭证。
            if error == .unauthorized {
                if !existingToken.isEmpty {
                    // 保留旧凭证：用户可能只是地址填错。
                } else {
                    credentials.clearToken()
                    hasStoredToken = false
                }
            }
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
