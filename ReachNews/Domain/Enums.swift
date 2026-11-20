import Foundation

// MARK: - 频道类型

enum ChannelKind: String, Equatable {
    case channel
    case follow

    init(apiValue: String?) {
        self = ChannelKind(rawValue: apiValue ?? "") ?? .channel
    }
}

// MARK: - 运行状态
//
// 三分法（契约）：进行中不产出日报；published 只呈现日报；missed 不是失败。

enum RunState: String, Equatable, CaseIterable {
    case queued
    case collecting
    case writing
    case published
    case failed
    case missed
    case cancelled

    init(apiValue: String?) {
        self = RunState(rawValue: apiValue ?? "") ?? .cancelled
    }

    var isRunning: Bool {
        switch self {
        case .queued, .collecting, .writing: return true
        case .published, .failed, .missed, .cancelled: return false
        }
    }

    var producedBrief: Bool { self == .published }
}

// MARK: - 错过原因
//
// 服务端会新增原因，未知值必须保留原始字符串，不得丢弃。

enum MissedReason: Equatable, Hashable {
    case noMaterial
    case queueTimeout
    case resumeWriting
    case unknown(String)

    static func parse(_ raw: String?) -> MissedReason? {
        guard let raw, !raw.isEmpty else { return nil }
        switch raw {
        case "no-material": return .noMaterial
        case "queue-timeout": return .queueTimeout
        case "resume-writing": return .resumeWriting
        default: return .unknown(raw)
        }
    }

    var rawValue: String {
        switch self {
        case .noMaterial: return "no-material"
        case .queueTimeout: return "queue-timeout"
        case .resumeWriting: return "resume-writing"
        case .unknown(let value): return value
        }
    }
}

// MARK: - 错误码
//
// 已实测六值；unknown 保留，不因为新增 code 就丢弃原因。
// not_found 的两义不参与判断：资源是否存在由调用方按路径决定。

enum APIErrorCode: Equatable {
    case unauthorized
    case notFound
    case invalidInput
    case busy
    case badRequest
    case internalError
    case unknown(String)

    static func parse(_ raw: String) -> APIErrorCode {
        switch raw {
        case "unauthorized": return .unauthorized
        case "not_found": return .notFound
        case "invalid_input": return .invalidInput
        case "busy": return .busy
        case "bad_request": return .badRequest
        case "internal_error": return .internalError
        default: return .unknown(raw)
        }
    }

    var rawValue: String {
        switch self {
        case .unauthorized: return "unauthorized"
        case .notFound: return "not_found"
        case .invalidInput: return "invalid_input"
        case .busy: return "busy"
        case .badRequest: return "bad_request"
        case .internalError: return "internal_error"
        case .unknown(let value): return value
        }
    }
}

// MARK: - 运行触发方式

enum RunTrigger: String, Equatable {
    case manual
    case schedule
    case regenerate
    case retry
    case resume
    case failureRetry = "failure-retry"
    case unknown

    static func parse(_ raw: String?) -> RunTrigger {
        RunTrigger(rawValue: raw ?? "") ?? .unknown
    }
}

// MARK: - 追问角色

enum AskRole: String, Equatable {
    case user
    case assistant

    static func parse(_ raw: String?) -> AskRole {
        AskRole(rawValue: raw ?? "") ?? .assistant
    }
}

// MARK: - 归一化后的 API 错误

enum APIError: Error, Equatable {
    case offline
    case transport(String)
    case unauthorized
    case notFound
    case invalidInput(String)
    case busy(String)
    case badRequest(String)
    case server(String)
    case decodingFailed
    case invalidConfiguration

    var errorCode: APIErrorCode? {
        switch self {
        case .unauthorized: return .unauthorized
        case .notFound: return .notFound
        case .invalidInput: return .invalidInput
        case .busy: return .busy
        case .badRequest: return .badRequest
        case .server: return .internalError
        case .offline, .transport, .decodingFailed, .invalidConfiguration: return nil
        }
    }

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }

    var isBusy: Bool {
        if case .busy = self { return true }
        return false
    }
}

// MARK: - 时间展示
//
// 服务端一律 UTC ISO 8601；展示按 Asia/Shanghai。不存储格式化字符串。

enum DisplayTime {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai") ?? TimeZone(secondsFromGMT: 8 * 3600)!

    private static func formatter(_ format: String, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = format
        return formatter
    }

    /// 「08:00」
    static func clock(_ date: Date, locale: Locale) -> String {
        formatter("HH:mm", locale: locale).string(from: date)
    }

    /// 「11月20日 08:00」
    static func monthDayTime(_ date: Date, locale: Locale) -> String {
        formatter("M月d日 HH:mm", locale: locale).string(from: date)
    }

    /// 「11月20日」
    static func monthDay(_ date: Date, locale: Locale) -> String {
        formatter("M月d日", locale: locale).string(from: date)
    }

    /// 「2026年11月20日」
    static func longDate(_ date: Date, locale: Locale) -> String {
        formatter("yyyy年M月d日", locale: locale).string(from: date)
    }

    /// 「11月20日 星期四」
    static func monthDayWeekday(_ date: Date, locale: Locale) -> String {
        formatter("M月d日 EEEE", locale: locale).string(from: date)
    }

    /// 日期分组的标题：今天、昨天，更早用日期。
    static func dayRuleTitle(_ date: Date, now: Date, locale: Locale, calendar: Calendar = .shanghai) -> String {
        if calendar.isDate(date, inSameDayAs: now) {
            return L10n.string("feed.day.today", locale: locale)
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) {
            return L10n.string("feed.day.yesterday", locale: locale)
        }
        return monthDay(date, locale: locale)
    }
}

extension Calendar {
    /// 统一按 Asia/Shanghai 解释日期与时刻。
    static var shanghai: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = DisplayTime.timeZone
        calendar.locale = Locale(identifier: "zh_Hans_CN")
        return calendar
    }
}
