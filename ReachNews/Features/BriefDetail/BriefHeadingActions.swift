import Foundation

// MARK: - 小标题与素材的匹配
//
// 正文的小标题（## 之类）在 Markdown 里只是文本，服务端没有「这个小标题对应哪条素材」
// 的字段，因此「查看原文」只能按文字判断：小标题文字被某个素材标题包含即算命中。
//
// 候选只来自正文 link 片段记录的 itemID —— 读者端不再渲染 sections，
// 不存在预先加载好的素材列表，点击时才按需取回这几条素材。
//
// 规则保守：只做忽略大小写的包含判断，不做分词、相似度或拼音推断。
// 多个命中取第一个，避免让用户面对一个莫名其妙的候选列表。

enum HeadingSourceMatcher {

    /// 小标题文字是否被素材标题包含。
    ///
    /// 只裁掉首尾空白与结尾的冒号（Markdown 小标题常写成「来源：」这类形式），
    /// 不做其它改写：改写越多，误命中越难解释。
    static func normalizedHeading(_ heading: String) -> String {
        heading
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "：:"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matches(heading: String, materialTitle: String) -> Bool {
        let needle = normalizedHeading(heading)
        guard !needle.isEmpty else { return false }
        let haystack = materialTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !haystack.isEmpty else { return false }
        return haystack.range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }

    /// 在候选素材里取第一个命中项；没有命中返回 nil。
    static func firstMatch(heading: String, candidates: [BriefHeadingCandidate]) -> BriefHeadingCandidate? {
        candidates.first { matches(heading: $0.title, materialTitle: $0.materialTitle) }
    }
}

// MARK: - 候选素材
//
// 一条正文 link 片段 + 取回后的素材标题。素材标题在点击时才可用，
// 因此这里把「片段」和「标题」分开存，标题未知时命中判断直接返回 nil。

struct BriefHeadingCandidate: Equatable, Hashable, Identifiable {
    /// 正文 link 片段里记录的素材 id。
    let itemID: String
    /// 素材标题；还没取回来时为 nil。
    var materialTitle: String?
    /// 素材原文地址；还没取回来时为 nil。
    var materialURL: URL?

    var id: String { itemID }

    var isResolved: Bool { materialTitle != nil && materialURL != nil }
}

// MARK: - 事件频道的预填内容
//
// 「跟踪事件」复用普通频道创建页，只是把名称与提示词预填好。
// 事件不是新的后端实体：提交时仍是一个普通频道，用户可改任意字段。

enum TrackedEventDraft {

    /// 预填名称：直接用小标题文字，去掉首尾空白与结尾冒号。
    static func name(heading: String) -> String {
        HeadingSourceMatcher.normalizedHeading(heading)
    }

    /// 预填提示词的本地化键；模板正文放在 Localizable.strings，
    /// 这样两种语言都能写出通顺的句子，而不是拼一段中英混排。
    static let promptKey = "brief.heading.track.prompt"

    /// 用实际的小标题文字渲染提示词模板。
    static func prompt(heading: String, locale: Locale) -> String {
        let name = name(heading: heading)
        return L10n.format(promptKey, locale: locale, name)
    }
}

// MARK: - 小标题动作层
//
// 点击正文小标题后弹出的两个动作。
// 用 confirmationDialog 而不是自制弹层：它是 iOS 惯用的动作选择，
// 并且天然支持「当前只有一个动作」的情况。

extension View {
    /// 把动作层挂到详情页上。`selection` 为 nil 时不显示。
    func briefHeadingActions(
        selection: Binding<HeadingActionContext?>,
        onOpenSource: @escaping (URL) -> Void,
        onTrackEvent: @escaping (String) -> Void
    ) -> some View {
        confirmationDialog(
            // 用 String 重载：Text 重载要求同时给 message，这里不需要第二行说明。
            selection.wrappedValue?.heading ?? "",
            isPresented: Binding(
                get: { selection.wrappedValue != nil },
                set: { if !$0 { selection.wrappedValue = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let context = selection.wrappedValue {
                if let url = context.sourceURL {
                    Button(L10n.string("brief.heading.openSource", locale: context.locale)) {
                        selection.wrappedValue = nil
                        onOpenSource(url)
                    }
                }
                Button(L10n.string("brief.heading.track", locale: context.locale)) {
                    selection.wrappedValue = nil
                    onTrackEvent(context.heading)
                }
            }
            Button(L10n.string("common.cancel", locale: selection.wrappedValue?.locale ?? .current), role: .cancel) {
                selection.wrappedValue = nil
            }
        }
    }
}

/// 动作层需要的上下文：点了哪个标题、命中的原文地址、渲染用的语言。
struct HeadingActionContext: Identifiable {
    let heading: String
    let sourceURL: URL?
    let locale: Locale

    var id: String { heading + "|" + (sourceURL?.absoluteString ?? "") }
}
