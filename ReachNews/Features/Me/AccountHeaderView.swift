import SwiftUI

// MARK: - 账号头部
//
// 「我的」页最上方的一条资料行：圆形头像 + 用户名 / 邮箱 / 套餐标识 + 行尾箭头。
// 三行数据全部来自服务端真实字段，见 `ProfileStore`。
// 本轮没有个人资料页，因此整行不可点：箭头只保留参考图的观感。

struct AccountHeaderView: View {
    let profile: ProfileStore
    @Environment(\.appLocale) private var locale

    private let avatarSize: CGFloat = 46

    var body: some View {
        HStack(spacing: Space.m) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.userName)
                    .font(TypeFace.heading(15))
                    .foregroundStyle(Palette.ink)
                    .lineLimit(1)
                    .accessibilityIdentifier("account-name")

                // 邮箱可能为 null：显示占位而不是空行，也不显示字面 null。
                Text(profile.email ?? L10n.string("me.account.email.empty", locale: locale))
                    .font(TypeFace.body(12))
                    .foregroundStyle(profile.email == nil ? Palette.inkTertiary : Palette.inkSecondary)
                    .lineLimit(1)
                    .accessibilityIdentifier("account-email")

                Text(profile.planLabel)
                    .font(TypeFace.label(11))
                    .foregroundStyle(Palette.inkTertiary)
                    .accessibilityIdentifier("account-plan")
            }
            Spacer(minLength: Space.s)
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Palette.inkTertiary)
        }
        .padding(.vertical, Space.xxs)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("me-account-header")
        .accessibilityLabel(Text(accessibilitySummary))
    }

    /// 有 `avatarUrl` 时按异步图片加载；没有、加载中或失败都显示缺省图形，
    /// 不会出现空白圆或破图。
    private var avatar: some View {
        ZStack {
            Circle().fill(Palette.paper)
            if let url = profile.avatarURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case let .success(image):
                        image.resizable().scaledToFill()
                    default:
                        placeholderGlyph
                    }
                }
                .clipShape(Circle())
            } else {
                placeholderGlyph
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .overlay { Circle().strokeBorder(Palette.line, lineWidth: 1) }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var placeholderGlyph: some View {
        Image(systemName: "person.fill")
            .font(.system(size: 20, weight: .regular))
            .foregroundStyle(Palette.inkTertiary)
    }

    private var accessibilitySummary: String {
        let separator = locale.identifier.lowercased().hasPrefix("zh") ? "，" : ", "
        return [profile.userName, profile.email, profile.planLabel]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: separator)
    }
}
