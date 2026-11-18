import Foundation
import Observation

struct Coverage: Codable, Equatable {
    let left: Int
    let center: Int
    let right: Int

    var total: Int { left + center + right }
    var label: String {
        if left < 10 { return "Blindspot on the left" }
        if right < 10 { return "Blindspot on the right" }
        return abs(left - right) > 25 ? "Polarized coverage" : "Balanced coverage"
    }
    var isBlindspot: Bool { left < 10 || right < 10 }
}

struct Perspective: Codable, Identifiable {
    let side: String
    let title: String
    let summary: String
    let quote: String
    let attribution: String
    var id: String { side }
}

struct Article: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let time: String
    let sources: Int
    let image: String
    let imageCredit: String
    let summary: String
    let coverage: Coverage
    let agreement: String
    let disagreement: String
    let perspectives: [Perspective]

    static func == (lhs: Article, rhs: Article) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct Collector: Identifiable, Hashable {
    let id: String
    let name: String
    let source: String
    let symbol: String
    let cadence: String
    let lastRun: String
    let itemCount: Int
    let status: String
    let tint: String
}

struct BriefingChannel: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let schedule: String
    let collectorIDs: [String]
    let unreadCount: Int
    let symbol: String
    let tint: String
    var isEnabled: Bool
}

struct TrackedEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let query: String
    let channelName: String
    let updates: Int
    let lastUpdated: String
    let symbol: String
    let tint: String
}

struct AIMessage: Identifiable, Hashable {
    let id = UUID()
    let role: String
    let text: String
}

struct Outlet: Identifiable {
    let id: String
    let name: String
    let monogram: String
    let side: String
    let factuality: String
    let ownership: String
    let url: URL

    static let samples: [Outlet] = [
        .init(id: "reuters", name: "Reuters", monogram: "R", side: "Center", factuality: "Very High", ownership: "Public company", url: URL(string: "https://www.reuters.com")!),
        .init(id: "ap", name: "Associated Press", monogram: "AP", side: "Center", factuality: "High", ownership: "Cooperative", url: URL(string: "https://apnews.com")!),
        .init(id: "guardian", name: "The Guardian", monogram: "G", side: "Left", factuality: "High", ownership: "Trust", url: URL(string: "https://www.theguardian.com")!),
        .init(id: "bbc", name: "BBC News", monogram: "BBC", side: "Center", factuality: "High", ownership: "Public media", url: URL(string: "https://www.bbc.com/news")!),
        .init(id: "fox", name: "Fox News", monogram: "FOX", side: "Right", factuality: "Mixed", ownership: "Media conglomerate", url: URL(string: "https://www.foxnews.com")!),
        .init(id: "dw", name: "Deutsche Welle", monogram: "DW", side: "Center", factuality: "High", ownership: "Public media", url: URL(string: "https://www.dw.com")!)
    ]
}

enum NewsCollection: String, CaseIterable, Identifiable, Hashable {
    case missed = "You Might Have Missed"
    case divergent = "Divergent Takes"
    case left = "Popular with the Left"
    case right = "Popular with the Right"
    var id: String { rawValue }
    var subtitle: String {
        switch self {
        case .missed: "Stories that deserve a second look."
        case .divergent: "One story. Very different perspectives."
        case .left: "The stories leading left-leaning coverage."
        case .right: "The stories leading right-leaning coverage."
        }
    }
    var symbol: String {
        switch self {
        case .missed: "arrow.counterclockwise"
        case .divergent: "arrow.down.right.and.arrow.up.left"
        case .left: "arrow.down.left"
        case .right: "arrow.down.right"
        }
    }
    func articles(from articles: [Article]) -> [Article] {
        switch self {
        case .missed: return articles.filter { $0.sources < 100 }
        case .divergent: return articles.filter { abs($0.coverage.left - $0.coverage.right) > 25 }
        case .left: return articles.sorted { $0.coverage.left > $1.coverage.left }
        case .right: return articles.sorted { $0.coverage.right > $1.coverage.right }
        }
    }
}

@MainActor @Observable
final class NewsStore {
    let articles: [Article]
    private(set) var savedIDs: Set<String>
    private(set) var followedTopics: Set<String>
    private(set) var followedCollections: Set<String>
    private(set) var readIDs: Set<String>
    let loadError: String?
    @ObservationIgnored private let defaults: UserDefaults

    static let topics = ["World", "United States", "Politics", "Environment", "Business", "Technology"]

    let collectors: [Collector] = [
        .init(id: "github", name: "GitHub Trending", source: "GitHub", symbol: "chevron.left.forwardslash.chevron.right", cadence: "Daily · 08:00", lastRun: "Today, 08:04", itemCount: 24, status: "Ready", tint: "blue"),
        .init(id: "x", name: "X watchlist", source: "X", symbol: "at", cadence: "Every 2 hours", lastRun: "12 min ago", itemCount: 18, status: "Watching", tint: "ink"),
        .init(id: "xiaohongshu", name: "小红书趋势", source: "小红书", symbol: "sparkles", cadence: "Daily · 09:30", lastRun: "Yesterday, 09:31", itemCount: 31, status: "Ready", tint: "coral")
    ]
    let channels: [BriefingChannel] = [
        .init(id: "ai", name: "AI & Agents", summary: "Models, products and the people building them.", schedule: "Every day · 08:30", collectorIDs: ["github", "x"], unreadCount: 12, symbol: "wand.and.stars", tint: "purple", isEnabled: true),
        .init(id: "tech", name: "Technology", summary: "The systems changing how we work and live.", schedule: "Every day · 12:00", collectorIDs: ["github", "x", "xiaohongshu"], unreadCount: 8, symbol: "cpu", tint: "blue", isEnabled: true),
        .init(id: "markets", name: "Markets", summary: "Signals and context for the next trading day.", schedule: "Weekdays · 17:30", collectorIDs: ["x"], unreadCount: 4, symbol: "chart.line.uptrend.xyaxis", tint: "gold", isEnabled: true),
        .init(id: "games", name: "Games", summary: "Releases, studios and the culture around play.", schedule: "Every day · 19:00", collectorIDs: ["xiaohongshu"], unreadCount: 0, symbol: "gamecontroller", tint: "coral", isEnabled: false)
    ]
    let trackedEvents: [TrackedEvent] = [
        .init(id: "open-models", title: "Open models race", query: "open source foundation models", channelName: "AI & Agents", updates: 17, lastUpdated: "38 min ago", symbol: "arrow.triangle.2.circlepath", tint: "purple"),
        .init(id: "chip-export", title: "AI chip export rules", query: "semiconductor export controls", channelName: "Markets", updates: 6, lastUpdated: "Yesterday", symbol: "scope", tint: "gold")
    ]

    init(defaults: UserDefaults = .standard, articles: [Article]? = nil) {
        self.defaults = defaults
        if let articles {
            self.articles = articles
            loadError = nil
        } else {
            do {
                guard let url = Bundle.main.url(forResource: "stories", withExtension: "json") else {
                    throw CocoaError(.fileNoSuchFile)
                }
                self.articles = try JSONDecoder().decode([Article].self, from: Data(contentsOf: url))
                loadError = nil
            } catch {
                self.articles = []
                loadError = "We couldn’t open the briefing. Please reinstall the app to restore its bundled stories."
            }
        }
        savedIDs = Set(defaults.stringArray(forKey: "savedStories") ?? [])
        followedTopics = Set(defaults.stringArray(forKey: "followedTopics") ?? ["World", "Politics"])
        followedCollections = Set(defaults.stringArray(forKey: "followedCollections") ?? [])
        readIDs = Set(defaults.stringArray(forKey: "readStories") ?? [])
    }

    var savedArticles: [Article] { articles.filter { savedIDs.contains($0.id) } }
    var blindspots: [Article] { articles.filter { $0.coverage.isBlindspot } }
    var followingArticles: [Article] { articles.filter { followedTopics.contains($0.category) } }

    func search(_ query: String, topic: String? = nil) -> [Article] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return articles.filter {
            (topic == nil || $0.category == topic) &&
            (term.isEmpty || "\($0.title) \($0.summary) \($0.category)".localizedCaseInsensitiveContains(term))
        }
    }
    func toggleSave(_ article: Article) {
        toggle(article.id, in: &savedIDs)
        defaults.set(Array(savedIDs), forKey: "savedStories")
    }
    func toggleTopic(_ topic: String) {
        toggle(topic, in: &followedTopics)
        defaults.set(Array(followedTopics), forKey: "followedTopics")
    }
    func toggleCollection(_ collection: NewsCollection) {
        toggle(collection.rawValue, in: &followedCollections)
        defaults.set(Array(followedCollections), forKey: "followedCollections")
    }
    func markRead(_ article: Article) {
        readIDs.insert(article.id)
        defaults.set(Array(readIDs), forKey: "readStories")
    }
    func resetReadingHistory() {
        readIDs.removeAll()
        defaults.removeObject(forKey: "readStories")
    }
    private func toggle(_ value: String, in set: inout Set<String>) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

