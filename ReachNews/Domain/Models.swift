import Foundation

// MARK: - 采集时间表
//
// 周一至周日各可配零到多个 HH:MM；未配置的星期不出现。所有时刻按 Asia/Shanghai 解释。

struct Schedule: Equatable, Hashable {
    struct Weekday: Equatable, Hashable, Identifiable, CaseIterable {
        let key: String
        let calendarIndex: Int
        let symbolKey: String

        var id: String { key }

        static var allCases: [Weekday] { all }

        static let all: [Weekday] = [
            Weekday(key: "mon", calendarIndex: 2, symbolKey: "weekday.mon"),
            Weekday(key: "tue", calendarIndex: 3, symbolKey: "weekday.tue"),
            Weekday(key: "wed", calendarIndex: 4, symbolKey: "weekday.wed"),
            Weekday(key: "thu", calendarIndex: 5, symbolKey: "weekday.thu"),
            Weekday(key: "fri", calendarIndex: 6, symbolKey: "weekday.fri"),
            Weekday(key: "sat", calendarIndex: 7, symbolKey: "weekday.sat"),
            Weekday(key: "sun", calendarIndex: 1, symbolKey: "weekday.sun")
        ]

        static func key(forCalendarIndex index: Int) -> String {
            all.first { $0.calendarIndex == index }?.key ?? "mon"
        }
    }

    /// 按周一…周日顺序保存每天的时刻，未配置的星期为空数组。
    private(set) var timesByWeekday: [String: [String]]

    static let weekdays: [Weekday] = Weekday.all

    init(timesByWeekday: [String: [String]] = [:]) {
        var sanitized: [String: [String]] = [:]
        for weekday in Schedule.weekdays {
            let times = timesByWeekday[weekday.key] ?? []
            sanitized[weekday.key] = Schedule.normalized(times)
        }
        self.timesByWeekday = sanitized
    }

    var isEmpty: Bool {
        timesByWeekday.values.allSatisfy(\.isEmpty)
    }

    func times(for weekday: Weekday) -> [String] {
        timesByWeekday[weekday.key] ?? []
    }

    func isEnabled(_ weekday: Weekday) -> Bool {
        !times(for: weekday).isEmpty
    }

    var activeWeekdays: [Weekday] {
        Schedule.weekdays.filter(isEnabled)
    }

    /// 全部时刻去重后按时间排序，供展示与「通常时刻」使用。
    var allTimes: [String] {
        Schedule.normalized(timesByWeekday.values.flatMap { $0 })
    }

    mutating func toggle(_ weekday: Weekday) {
        if isEnabled(weekday) {
            timesByWeekday[weekday.key] = []
        } else {
            let fallback = allTimes.first ?? "08:00"
            timesByWeekday[weekday.key] = [fallback]
        }
    }

    mutating func addTime(_ time: String, to weekday: Weekday) {
        var times = times(for: weekday)
        guard !times.contains(time) else { return }
        times.append(time)
        timesByWeekday[weekday.key] = Schedule.normalized(times)
    }

    mutating func removeTime(_ time: String, from weekday: Weekday) {
        timesByWeekday[weekday.key] = times(for: weekday).filter { $0 != time }
    }

    /// 把选中的星期对齐到某个时刻（编辑页里「统一加成同一时间」的行为）。
    mutating func applyTimeToAllEnabled(_ time: String) {
        for weekday in activeWeekdays {
            timesByWeekday[weekday.key] = Schedule.normalized([time])
        }
    }

    private static func normalized(_ times: [String]) -> [String] {
        var seen = Set<String>()
        return times
            .filter { isValid($0) }
            .filter { seen.insert($0).inserted }
            .sorted()
    }

    static func isValid(_ value: String) -> Bool {
        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2,
              let hour = Int(parts[0]), let minute = Int(parts[1]),
              parts[0].count == 2, parts[1].count == 2,
              (0...23).contains(hour), (0...59).contains(minute) else {
            return false
        }
        return true
    }
}

// MARK: - 会话凭证
//
// 后端以账号密码换 7 天会话凭证；本地保存 token 与过期时刻，
// 过期或收到 401 都应回到登录页，没有 refresh 接口。

struct AuthSession: Equatable {
    let token: String
    let expiresAt: Date
    let userName: String

    func isExpired(now: Date = Date()) -> Bool {
        expiresAt <= now
    }
}

// MARK: - 频道

struct Channel: Identifiable, Equatable, Hashable {
    let id: String
    var name: String
    var prompt: String
    var tone: String
    var schedule: Schedule
    var enabled: Bool
    var connectorIDs: [String]
    var lastBriefAt: Date?
    var kind: ChannelKind
    var createdAt: Date
    var updatedAt: Date

    /// 未配置连接器却处于启用状态 —— 运行必然错过（no-material）。
    var hasNoConnectors: Bool {
        connectorIDs.isEmpty
    }

    /// 需要提示「运行将不会产出日报」的情形。
    var warnsAboutMissingConnectors: Bool {
        enabled && hasNoConnectors
    }
}

// MARK: - 日报

struct BriefSection: Identifiable, Equatable, Hashable {
    let title: String
    let entries: [Entry]

    var id: String { title }
}

/// 日报分组内的一条聚合。字段名在 payload 里是 `items`，但它是条目，不是素材。
struct Entry: Identifiable, Equatable, Hashable {
    let title: String
    let summary: String
    let materialIDs: [String]

    var id: String { title + "|" + materialIDs.joined(separator: ",") }
}

struct Brief: Identifiable, Equatable, Hashable {
    let id: String
    let channelID: String
    let title: String
    let sections: [BriefSection]
    let memorySummary: String
    let createdAt: Date

    var entryCount: Int {
        sections.reduce(0) { $0 + $1.entries.count }
    }

    /// 素材数：本期全部条目的 materialIds 去重计数。
    var materialCount: Int {
        var ids = Set<String>()
        for section in sections {
            for entry in section.entries {
                ids.formUnion(entry.materialIDs)
            }
        }
        return ids.count
    }

    var allMaterialIDs: [String] {
        var ordered: [String] = []
        var seen = Set<String>()
        for section in sections {
            for entry in section.entries {
                for id in entry.materialIDs where seen.insert(id).inserted {
                    ordered.append(id)
                }
            }
        }
        return ordered
    }
}

// MARK: - 素材
//
// `content` 只解析不展示：RSS 是原始 XML，GitHub 是原始 JSON 字符串。

struct Material: Identifiable, Equatable, Hashable {
    let id: String
    let title: String
    let url: URL
    let publishedAt: Date?
    let sourceLabel: String?
    let content: String

    var host: String {
        url.host()?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
    }

    /// 素材行左侧的两字母方块。
    var monogram: String {
        let name = host.split(separator: ".").first.map(String.init) ?? host
        let letters = name.prefix(2).uppercased()
        return letters.isEmpty ? "··" : String(letters)
    }
}

// MARK: - 运行

struct Run: Identifiable, Equatable, Hashable {
    let id: String
    let channelID: String?
    let state: RunState
    let trigger: RunTrigger
    let startedAt: Date?
    let finishedAt: Date?
    let missedReason: MissedReason?
    let createdAt: Date
}

// MARK: - 追问

struct AskTurn: Identifiable, Equatable, Hashable {
    let id: String
    let role: AskRole
    let message: String
    let createdAt: Date
}

// MARK: - 轮询

/// `/cursor` 返回的新增日报摘要（snake_case 已归一化）。
struct CursorBrief: Identifiable, Equatable, Hashable {
    let id: String
    let channelID: String
    let title: String
    let createdAt: Date
}

/// `/cursor` 返回的频道摘要。`enabled` 在远端是整数 1/0，此处已是 Bool。
struct CursorChannel: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let enabled: Bool
    let updatedAt: Date
}

struct CursorPayload: Equatable {
    let briefs: [CursorBrief]
    let channels: [CursorChannel]

    var latestBriefAt: Date? {
        briefs.map(\.createdAt).max()
    }
}

// MARK: - 分页

struct Page<Element> {
    let items: [Element]
    let nextCursor: String?
}

// MARK: - 频道编辑草稿
//
// 保存时只提交被改动的字段。

struct ChannelDraft: Equatable {
    var name: String
    var prompt: String
    var tone: String
    var schedule: Schedule
    var enabled: Bool

    init(channel: Channel) {
        name = channel.name
        prompt = channel.prompt
        tone = channel.tone
        schedule = channel.schedule
        enabled = channel.enabled
    }

    func changes(against channel: Channel) -> ChannelChanges {
        var changes = ChannelChanges()
        if name != channel.name { changes.name = name }
        if prompt != channel.prompt { changes.prompt = prompt }
        if tone != channel.tone { changes.tone = tone }
        if schedule != channel.schedule { changes.schedule = schedule }
        if enabled != channel.enabled { changes.enabled = enabled }
        return changes
    }
}

/// 只包含需要提交的字段；序列化时省略未改动的键。
struct ChannelChanges: Equatable {
    var name: String?
    var prompt: String?
    var tone: String?
    var schedule: Schedule?
    var enabled: Bool?

    var isEmpty: Bool {
        name == nil && prompt == nil && tone == nil && schedule == nil && enabled == nil
    }

    var changedFieldNames: [String] {
        var names: [String] = []
        if name != nil { names.append("name") }
        if prompt != nil { names.append("prompt") }
        if tone != nil { names.append("tone") }
        if schedule != nil { names.append("schedule") }
        if enabled != nil { names.append("enabled") }
        return names
    }
}

// MARK: - 频道创建入口的可用性
//
// ADR 0004：`/api/v1` 没有连接器枚举端点，创建出来必然是 missed 的频道，
// 因此在端点可用前不落地保存动作。

enum ChannelCreationAvailability {
    static let isAvailable = false
}
