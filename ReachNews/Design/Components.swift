import SwiftUI

// MARK: - 频道标识点

struct ChannelDot: View {
    let channelID: String
    var diameter: CGFloat = 7

    var body: some View {
        Circle()
            .fill(ChannelTint.color(for: channelID))
            .frame(width: diameter, height: diameter)
            .accessibilityHidden(true)
    }
}

// MARK: - 点分隔符

struct DotSeparator: View {
    var body: some View {
        Circle()
            .fill(Palette.inkTertiary)
            .frame(width: 3, height: 3)
            .accessibilityHidden(true)
    }
}

// MARK: - 元信息行

struct MetaLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(TypeFace.condensed(11.5, weight: .medium))
            .foregroundStyle(Palette.inkTertiary)
    }
}

// MARK: - 日期分组标题

struct DayRule: View {
    let title: String

    var body: some View {
        HStack(spacing: Space.s) {
            Text(title)
                .font(TypeFace.label(11))
                .tracking(1.1)
                .foregroundStyle(Palette.inkTertiary)
            Rectangle()
                .fill(Palette.line)
                .frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 状态 chip

struct StatusChip: View {
    enum Style {
        case running
        case missed
        case failed
        case neutral

        var background: Color {
            switch self {
            case .running: return Palette.runningBackground
            case .missed: return Palette.missedBackground
            case .failed: return Palette.failedBackground
            case .neutral: return Palette.missedBackground
            }
        }

        var foreground: Color {
            switch self {
            case .running: return Palette.runningForeground
            case .missed: return Palette.missedForeground
            case .failed: return Palette.failedForeground
            case .neutral: return Palette.missedForeground
            }
        }
    }

    let style: Style
    let text: String

    var body: some View {
        Text(text)
            .font(TypeFace.label(10))
            .foregroundStyle(style.foreground)
            .padding(.horizontal, Space.xs)
            .padding(.vertical, 2.5)
            .background(style.background, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }
}

// MARK: - 分组吸顶标题

struct SectionStickyHeader: View {
    let title: String
    let count: Int
    let locale: Locale

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(title)
                .font(TypeFace.heading(12.5))
                .foregroundStyle(Palette.ink)
            Text(L10n.format("briefDetail.entryCount", locale: locale, count))
                .font(TypeFace.condensed(10.5, weight: .medium))
                .foregroundStyle(Palette.inkTertiary)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.xl)
        .padding(.vertical, Space.s)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Palette.line).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - 圆形导航按钮

struct NavCircleButton: View {
    let systemImage: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Palette.inkSecondary)
                .frame(width: 34, height: 34)
                .background(.regularMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - 主按钮

struct PrimaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeFace.heading(14))
                .foregroundStyle(Palette.canvas)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Palette.ink))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 次按钮

struct SecondaryButton: View {
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(TypeFace.heading(14))
                .foregroundStyle(Palette.inkSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(Palette.chip))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 空态 / 错误态

struct MessageStateView: View {
    enum Kind {
        case empty
        case error(APIError)
        case informational
    }

    let title: String
    var message: String?
    var kind: Kind = .informational
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.m) {
            Image(systemName: iconName)
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(iconColor)
            Text(title)
                .font(TypeFace.heading(15))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(TypeFace.body(13))
                    .foregroundStyle(Palette.inkTertiary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(TypeFace.heading(13.5))
                    .foregroundStyle(Palette.canvas)
                    .padding(.horizontal, Space.l)
                    .padding(.vertical, Space.s)
                    .background(Capsule().fill(Palette.ink))
                    .padding(.top, Space.xxs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Space.xxl)
        .padding(.vertical, 44)
    }

    private var iconName: String {
        switch kind {
        case .empty: return "tray"
        case .error(let error): return error.isOffline ? "wifi.slash" : "exclamationmark.triangle"
        case .informational: return "info.circle"
        }
    }

    private var iconColor: Color {
        switch kind {
        case .error: return Palette.failedForeground
        case .empty, .informational: return Palette.inkTertiary
        }
    }
}

// MARK: - 加载指示

struct LoadingLine: View {
    var text: String

    var body: some View {
        HStack(spacing: Space.s) {
            ProgressView()
                .controlSize(.small)
            Text(text)
                .font(TypeFace.body(11.5))
                .foregroundStyle(Palette.inkTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Space.l)
    }
}

// MARK: - 错误提示条

struct InlineNotice: View {
    enum Kind {
        case warning
        case error
    }

    let text: String
    var detail: String?
    var kind: Kind = .warning

    var body: some View {
        HStack(alignment: .top, spacing: Space.s) {
            Image(systemName: kind == .warning ? "exclamationmark.triangle.fill" : "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(foreground)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                Text(text)
                    .font(TypeFace.body(12))
                    .foregroundStyle(foreground)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(TypeFace.body(11))
                        .foregroundStyle(foreground.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Space.m)
        .padding(.vertical, 11)
        .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var foreground: Color {
        switch kind {
        case .warning: return Palette.failedForeground
        case .error: return Palette.failedForeground
        }
    }

    private var background: Color {
        switch kind {
        case .warning, .error: return Palette.failedBackground
        }
    }
}

// MARK: - 开发中占位
//
// 稿子里有、但服务端未提供数据支撑的位置统一用这个组件标注。

struct FeatureInProgressView: View {
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Label {
                Text(String(localized: "common.featureInProgress"))
                    .font(TypeFace.label(11))
            } icon: {
                Image(systemName: "hammer")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(Palette.inkTertiary)
            if let detail {
                Text(detail)
                    .font(TypeFace.body(10.5))
                    .foregroundStyle(Palette.inkTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .background(RoundedRectangle(cornerRadius: Radius.small, style: .continuous).fill(Palette.chip))
    }
}

// MARK: - 品牌标识

struct BrandMark: View {
    let assetName: String
    var size: CGFloat = 26

    var body: some View {
        Image(assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

// MARK: - 开关
//
// 频道卡的 enabled 开关；提交中禁用，避免重复点击。

struct ChannelToggle: View {
    let isOn: Bool
    let isPending: Bool
    let action: (Bool) -> Void

    var body: some View {
        Button {
            action(!isOn)
        } label: {
            Capsule()
                .fill(isOn ? Palette.ink : Palette.lineStrong)
                .frame(width: 38, height: 22)
                .overlay {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 17, height: 17)
                        .padding(2.5)
                        .frame(maxWidth: .infinity, alignment: isOn ? .trailing : .leading)
                }
                .opacity(isPending ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isPending)
        .accessibilityLabel(Text(String(localized: "channel.toggle.accessibility")))
        .accessibilityValue(Text(isOn ? String(localized: "common.on") : String(localized: "common.off")))
    }
}
