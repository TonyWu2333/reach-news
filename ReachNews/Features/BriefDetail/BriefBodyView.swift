import SwiftUI

// MARK: - 正文渲染
//
// 正文只有段落与行内链接：没有小标题、加粗或图片，因此不做 Markdown 解析。
// 按长文阅读排版：段落之间留出正常正文间距，行高放宽。
// body 缺失或全为空白段落时，显示一句说明，不回退到分组列表。

struct BriefBodyView: View {
    let body: BriefBody?
    var onOpenURL: (URL) -> Void

    @Environment(\.appLocale) private var locale

    /// 与 Brief.hasReadableBody 保持一致：空白段落不算正文。
    private var readable: Bool {
        guard let body else { return false }
        return !body.isEmpty
    }

    var body: some View {
        if readable, let body {
            VStack(alignment: .leading, spacing: Space.l) {
                ForEach(Array(body.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                    // 用 AttributedString 承载链接：Text 的字符串拼接无法绑定点击，
                    // 富文本的 link 属性才会真正把片段变成可点链接。
                    Text(paragraph.attributed)
                        .font(TypeFace.body(16))
                        .lineSpacing(7)
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .environment(\.openURL, OpenURLAction { url in
                            onOpenURL(url)
                            return .handled
                        })
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityIdentifier("brief-body")
        } else {
            Text(L10n.string("brief.body.empty", locale: locale))
                .font(TypeFace.body(14))
                .foregroundStyle(Palette.inkTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Space.m)
                .accessibilityIdentifier("brief-body-empty")
        }
    }
}

// MARK: - 段落富文本
//
// 文字片段原样保留；链接片段带 URL 属性，因此可点。
// 未知或降级片段在 DTO 层已经变成纯文字，这里只处理两种已归一化的片段。

extension BriefParagraph {
    var attributed: AttributedString {
        var result = AttributedString()
        for segment in segments {
            var piece = AttributedString(segment.displayText)
            if let url = segment.linkURL {
                piece.link = url
                piece.underlineStyle = .single
                piece.foregroundColor = Palette.runningForeground
            }
            result += piece
        }
        return result
    }
}
