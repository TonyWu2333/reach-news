import Foundation
import Security

// MARK: - 凭证存取协议

protocol CredentialProviding: AnyObject {
    func token() -> String?
    func store(token: String) throws
    func clearToken()
}

// MARK: - Keychain
//
// Token 只存 Keychain，不进 UserDefaults，不写日志。
// 失败时抛出明确错误，不静默吞掉。

enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case emptyToken
}

final class KeychainCredentials: CredentialProviding {
    private let service: String
    private let account: String

    init(service: String = "com.tangsong404.reachnews", account: String = "bearer-token") {
        self.service = service
        self.account = account
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    func token() -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func store(token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw KeychainError.emptyToken }
        let data = Data(trimmed.utf8)

        let updateStatus = SecItemUpdate(
            baseQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )

        switch updateStatus {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            var insert = baseQuery
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(insert as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
        default:
            throw KeychainError.unexpectedStatus(updateStatus)
        }
    }

    func clearToken() {
        SecItemDelete(baseQuery as CFDictionary)
    }
}

// MARK: - 应用偏好
//
// 只存用户偏好与一个轮询基线时间戳（ADR 0003）。
// 不缓存任何日报、素材或运行内容。

protocol PreferencesStoring: AnyObject {
    var baseURLString: String { get set }
    var languagePreference: String { get set }
    var lastSeenAt: Date? { get set }
}

final class UserDefaultsPreferences: PreferencesStoring {
    private enum Keys {
        static let baseURL = "preferences.baseURL"
        static let language = "preferences.language"
        // 轮询基线单独命名、单独存储，与任何内容缓存无关。
        static let lastSeenAt = "polling.baseline.lastSeenAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var baseURLString: String {
        get { defaults.string(forKey: Keys.baseURL) ?? BaseURLDefaults.host }
        set { defaults.set(newValue, forKey: Keys.baseURL) }
    }

    var languagePreference: String {
        get { defaults.string(forKey: Keys.language) ?? LanguagePreference.system.rawValue }
        set { defaults.set(newValue, forKey: Keys.language) }
    }

    var lastSeenAt: Date? {
        get {
            let interval = defaults.double(forKey: Keys.lastSeenAt)
            return interval > 0 ? Date(timeIntervalSince1970: interval) : nil
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Keys.lastSeenAt)
            } else {
                defaults.removeObject(forKey: Keys.lastSeenAt)
            }
        }
    }
}

// MARK: - 语言偏好

enum LanguagePreference: String, CaseIterable, Identifiable {
    case system
    case chinese = "zh-Hans"
    case english = "en"

    var id: String { rawValue }

    var labelKey: String {
        switch self {
        case .system: return "preferences.language.system"
        case .chinese: return "preferences.language.chinese"
        case .english: return "preferences.language.english"
        }
    }

    var locale: Locale {
        switch self {
        case .system: return .autoupdatingCurrent
        case .chinese: return Locale(identifier: "zh-Hans")
        case .english: return Locale(identifier: "en")
        }
    }
}

// MARK: - 本机收藏
//
// 收藏仅存本机，不同步服务端，不改变服务端任何状态（GLOSSARY「收藏」）。

protocol SavedBriefsStoring: AnyObject {
    var savedBriefIDs: Set<String> { get }
    func toggle(_ briefID: String) -> Set<String>
}

final class UserDefaultsSavedBriefs: SavedBriefsStoring {
    private let key = "saved.briefs"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var savedBriefIDs: Set<String> {
        Set(defaults.stringArray(forKey: key) ?? [])
    }

    @discardableResult
    func toggle(_ briefID: String) -> Set<String> {
        var ids = savedBriefIDs
        if ids.contains(briefID) {
            ids.remove(briefID)
        } else {
            ids.insert(briefID)
        }
        defaults.set(Array(ids), forKey: key)
        return ids
    }
}
