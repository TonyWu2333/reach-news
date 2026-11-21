import Foundation
import SwiftUI

// MARK: - 色值工具

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

// MARK: - 语义 token
//
// 两套视觉语言并存（ADR 0001）：日报、频道、我的走「编辑风」；追问走「近单色工具风」。
// 视图内一律引用这里的 token，不写字面色值。

enum Palette {
    // 编辑风：日报与频道
    static let canvas = Color(hex: 0xFBFAF7)
    static let paper = Color(hex: 0xF1EFE9)
    static let surface = Color(hex: 0xFFFFFF)
    static let ink = Color(hex: 0x14140F)
    static let inkSecondary = Color(hex: 0x53514A)
    static let inkTertiary = Color(hex: 0x8B877E)
    static let line = Color(hex: 0x14140F).opacity(0.10)
    static let lineStrong = Color(hex: 0x14140F).opacity(0.16)
    static let chip = Color(hex: 0xF2F0EA)
    static let field = Color(hex: 0xF2F0EA)

    // 追问风：近单色
    static let askBackground = Color(hex: 0xF6F5F2)
    static let askSurface = Color(hex: 0xFFFFFF)
    static let askBubble = Color(hex: 0xEFEDE8)
    static let askUser = Color(hex: 0x121211)
    static let askUserText = Color(hex: 0xF7F6F4)

    // 状态：运行中 / 错过 / 失败
    static let runningBackground = Color(hex: 0xEAF0EC)
    static let runningForeground = Color(hex: 0x3D6B5C)
    static let missedBackground = Color(hex: 0xEFEDE7)
    static let missedForeground = Color(hex: 0x53514A)
    static let failedBackground = Color(hex: 0xFAF0EC)
    static let failedForeground = Color(hex: 0xA5452A)

    // 频道标识：steel / moss / clay / plum
    static let channelTints: [Color] = [
        Color(hex: 0x4E6E8E),
        Color(hex: 0x3D6B5C),
        Color(hex: 0xA9714B),
        Color(hex: 0x7A5A78)
    ]
}

// MARK: - 频道标识色
//
// 由 channelId 稳定映射，保证同一频道在列表、详情、编辑页取到同一色。

enum ChannelTint {
    static func color(for channelID: String) -> Color {
        var accumulator: UInt32 = 0
        for scalar in channelID.unicodeScalars {
            accumulator = accumulator &* 31 &+ scalar.value
        }
        let index = Int(accumulator % UInt32(Palette.channelTints.count))
        return Palette.channelTints[index]
    }
}

// MARK: - 圆角与间距

enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let pill: CGFloat = 999
}

enum Space {
    static let hairline: CGFloat = 1
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 6
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 22
    static let xxl: CGFloat = 28
}

// MARK: - 字体
//
// 中文用系统字（苹方／思源黑），数字用压缩体（对应稿子的 Arial Narrow 角色）。

enum TypeFace {
    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    static func title(_ size: CGFloat) -> Font {
        .system(size: size, weight: .bold)
    }

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold)
    }

    static func body(_ size: CGFloat) -> Font {
        .system(size: size, weight: .regular)
    }

    static func label(_ size: CGFloat) -> Font {
        .system(size: size, weight: .medium)
    }

    /// 苹果风格的脚注尺寸，仅用于确实需要说明的次要信息。
    static let footnote: Font = .footnote

    static func condensed(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).width(.condensed)
    }

    static func monospacedDigits(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight).monospacedDigit()
    }
}

// MARK: - 本地化辅助
//
// 按 locale 找到对应的 .lproj bundle 再取值，这样界面语言偏好能真正覆盖系统语言。
// 需要 String 而非 Text 的场合（错误文案、格式化、无障碍标签）统一走这里。

enum L10n {
    static func bundle(for locale: Locale) -> Bundle {
        let identifier = locale.identifier.replacingOccurrences(of: "_", with: "-")
        var candidates = [identifier]
        if let language = identifier.split(separator: "-").first {
            candidates.append(String(language))
        }
        candidates.append("zh-Hans")
        for candidate in candidates {
            if let path = Bundle.main.path(forResource: candidate, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return .main
    }

    static func string(_ key: String, locale: Locale) -> String {
        bundle(for: locale).localizedString(forKey: key, value: key, table: nil)
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let template = string(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }
}
