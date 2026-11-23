import Foundation

// MARK: - 日报正文
//
// body 是模型写的精写成稿：段落 + 行内链接，没有小标题、加粗或图片。
// 它和 sections 不是同一份内容的两种格式：正文可以只引用部分素材，
// 读者端只呈现正文，sections 不再进入这个界面。

struct BriefBody: Equatable, Hashable {
    let paragraphs: [BriefParagraph]

    /// 全部段落都没有可读文字时按「无正文」处理，避免渲染出空白块。
    /// 只有空白字符（空格、换行）也算没有文字。
    var isEmpty: Bool {
        paragraphs.allSatisfy { paragraph in
            paragraph.segments.allSatisfy {
                $0.displayText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    static func == (lhs: BriefBody, rhs: BriefBody) -> Bool {
        lhs.paragraphs == rhs.paragraphs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(paragraphs)
    }
}

struct BriefParagraph: Equatable, Hashable, Identifiable {
    let segments: [BriefSegment]

    var id: String {
        segments.map(\.identity).joined(separator: "|")
    }
}

// MARK: - 正文片段
//
// type 只有 text 与 link 两种；link 一定带真实素材 URL。
// url 缺失或不合法时降级为纯文字，不生成死链；
// 未知 type 也按纯文字处理，保证内容不丢。

enum BriefSegment: Equatable, Hashable {
    case text(String)
    case link(text: String, url: URL, itemID: String?)

    /// 渲染用的文字；两种片段都取自己的 text。
    var displayText: String {
        switch self {
        case .text(let text): return text
        case .link(let text, _, _): return text
        }
    }

    /// 可点开的链接；纯文字片段为 nil。
    var linkURL: URL? {
        if case .link(_, let url, _) = self { return url }
        return nil
    }

    /// 引用到的素材 id，仅用于定位原文，不参与业务判断。
    var itemID: String? {
        if case .link(_, _, let itemID) = self { return itemID }
        return nil
    }

    /// 段落内部去重与比对用的稳定标识。
    var identity: String {
        switch self {
        case .text(let text):
            return "t:\(text)"
        case .link(let text, let url, let itemID):
            return "l:\(text)|\(url.absoluteString)|\(itemID ?? "")"
        }
    }
}
