import SwiftUI
import Observation

@MainActor @Observable
final class LiquidGlassSettings {
    var opacity: Double = 0.68
    var blur: Double = 18
    var cornerRadius: Double = 26
    var tint: Double = 0.10

    func reset() {
        opacity = 0.68
        blur = 18
        cornerRadius = 26
        tint = 0.10
    }
}

enum NewsTheme {
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.065)
    static let secondary = Color(red: 0.46, green: 0.46, blue: 0.44)
    static let paper = Color(red: 0.965, green: 0.965, blue: 0.95)
    static let card = Color(red: 0.955, green: 0.955, blue: 0.955)
    static let line = Color.black.opacity(0.12)
    static let left = Color(red: 0.025, green: 0.56, blue: 0.79)
    static let center = Color(red: 0.43, green: 0.43, blue: 0.42)
    static let right = Color(red: 0.97, green: 0.34, blue: 0.20)
    static let gold = Color(red: 0.81, green: 0.74, blue: 0.56)
    static let purple = Color(red: 0.52, green: 0.41, blue: 0.72)

    static func headline(_ size: CGFloat) -> Font {
        .custom("BarlowCondensed-Bold", size: size, relativeTo: .largeTitle)
    }
    static func side(_ side: String) -> Color {
        side == "Left" ? left : side == "Right" ? right : center
    }
    static func collection(_ collection: NewsCollection) -> Color {
        switch collection {
        case .missed: Color(red: 0.92, green: 0.36, blue: 0.12)
        case .divergent: Color(red: 0.22, green: 0.22, blue: 0.22)
        case .left: left
        case .right: right
        }
    }
}

struct LiquidGlassModifier: ViewModifier {
    @Environment(LiquidGlassSettings.self) private var settings
    var radius: CGFloat?
    var tintColor: Color = .white

    func body(content: Content) -> some View {
        let resolvedRadius = radius ?? CGFloat(settings.cornerRadius)
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
            .background(tintColor.opacity(0.22 + settings.tint * settings.opacity), in: RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
            .overlay {
                ZStack {
                    RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(settings.opacity * 0.34), .clear, .white.opacity(settings.opacity * 0.12)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    Circle()
                        .fill(.white.opacity(settings.opacity * 0.22))
                        .frame(width: 76, height: 32)
                        .blur(radius: CGFloat(max(4, settings.blur / 2)))
                        .offset(x: -54, y: -25)
                }
                .clipShape(RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: resolvedRadius, style: .continuous)
                    .strokeBorder(.white.opacity(settings.opacity * 0.55), lineWidth: 1)
            }
            .shadow(color: NewsTheme.ink.opacity(0.15), radius: CGFloat(settings.blur), y: 8)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat? = nil, tint: Color = .white) -> some View {
        modifier(LiquidGlassModifier(radius: cornerRadius, tintColor: tint))
    }
}

struct LiquidLensShape: Shape {
    var bulge: CGFloat

    func path(in rect: CGRect) -> Path {
        let inset: CGFloat = 3
        let left = rect.minX + inset
        let right = rect.maxX - inset
        let top = rect.minY + inset
        let bottom = rect.maxY - inset
        let radius = min(20, rect.height / 2)
        var path = Path()
        path.move(to: CGPoint(x: left + radius, y: top))
        path.addCurve(to: CGPoint(x: right - radius, y: top), control1: CGPoint(x: rect.midX - rect.width * 0.22, y: top - bulge), control2: CGPoint(x: rect.midX + rect.width * 0.22, y: top - bulge))
        path.addCurve(to: CGPoint(x: right, y: bottom - radius), control1: CGPoint(x: right + bulge, y: rect.midY - rect.height * 0.22), control2: CGPoint(x: right + bulge, y: rect.midY + rect.height * 0.22))
        path.addCurve(to: CGPoint(x: left + radius, y: bottom), control1: CGPoint(x: rect.midX + rect.width * 0.22, y: bottom + bulge), control2: CGPoint(x: rect.midX - rect.width * 0.22, y: bottom + bulge))
        path.addCurve(to: CGPoint(x: left, y: top + radius), control1: CGPoint(x: left - bulge, y: rect.midY + rect.height * 0.22), control2: CGPoint(x: left - bulge, y: rect.midY - rect.height * 0.22))
        path.closeSubpath()
        return path
    }
}

struct BiasBar: View {
    let coverage: Coverage
    var showLabels = false

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { geometry in
                HStack(spacing: 2) {
                    segment(coverage.left, color: NewsTheme.left, width: geometry.size.width)
                    segment(coverage.center, color: NewsTheme.center, width: geometry.size.width)
                    segment(coverage.right, color: NewsTheme.right, width: geometry.size.width)
                }
            }
            .frame(height: showLabels ? 10 : 7)
            .clipShape(Capsule())
            if showLabels {
                HStack {
                    legend("Left", value: coverage.left, color: NewsTheme.left)
                    Spacer()
                    legend("Center", value: coverage.center, color: NewsTheme.center)
                    Spacer()
                    legend("Right", value: coverage.right, color: NewsTheme.right)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Coverage: left \(coverage.left) percent, center \(coverage.center) percent, right \(coverage.right) percent")
    }

    @ViewBuilder private func segment(_ value: Int, color: Color, width: CGFloat) -> some View {
        if value > 0 {
            color.frame(width: max(0, width - 4) * CGFloat(value) / CGFloat(max(coverage.total, 1)))
        }
    }
    private func legend(_ title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text("\(title) \(value)%").font(.caption2).foregroundStyle(NewsTheme.secondary)
        }
    }
}

struct CoverageLabel: View {
    let coverage: Coverage
    var body: some View {
        HStack(spacing: 6) {
            if coverage.isBlindspot {
                Image(systemName: "circle.lefthalf.filled").font(.caption.bold())
            } else {
                HStack(spacing: 2) {
                    ForEach([NewsTheme.left, NewsTheme.center, NewsTheme.right], id: \.self) { color in
                        RoundedRectangle(cornerRadius: 1).fill(color).frame(width: 4, height: 10)
                    }
                }
            }
            Text(coverage.label).font(.caption.weight(.medium))
        }
    }
}

struct StoryImage: View {
    let article: Article
    var height: CGFloat = 200
    var body: some View {
        ZStack {
            LinearGradient(colors: gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: article.image == "forest" ? "tree.fill" : article.image == "capitol" ? "building.columns.fill" : article.image == "city" ? "building.2.fill" : "cloud.heavyrain.fill")
                .font(.system(size: 64, weight: .light)).foregroundStyle(.white.opacity(0.7))
        }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .clipped()
            .accessibilityLabel(article.imageCredit)
    }

    private var gradientColors: [Color] {
        switch article.image {
        case "forest": [Color(red: 0.1, green: 0.25, blue: 0.17), Color(red: 0.35, green: 0.5, blue: 0.25)]
        case "capitol": [Color(red: 0.08, green: 0.1, blue: 0.15), Color(red: 0.42, green: 0.23, blue: 0.16)]
        case "city": [Color(red: 0.12, green: 0.22, blue: 0.35), Color(red: 0.5, green: 0.55, blue: 0.62)]
        default: [Color(red: 0.18, green: 0.38, blue: 0.48), Color(red: 0.62, green: 0.72, blue: 0.76)]
        }
    }
}

struct SectionHeading: View {
    let title: String
    var subtitle: String? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(NewsTheme.headline(36)).foregroundStyle(NewsTheme.ink)
            if let subtitle {
                Text(subtitle).font(.subheadline).foregroundStyle(NewsTheme.secondary).lineSpacing(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Tag: View {
    let text: String
    var color: Color = NewsTheme.ink
    var filled = false
    var body: some View {
        Text(text)
            .font(.caption2.weight(.medium))
            .foregroundStyle(filled ? .white : color)
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(filled ? color : color.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct RoundIcon: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 18, weight: .medium))
            .frame(width: 44, height: 44)
            .background(NewsTheme.card, in: Circle())
    }
}

struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 34, weight: .light))
            Text(title).font(.title3.bold())
            Text(message).font(.subheadline).foregroundStyle(NewsTheme.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.horizontal, 32).padding(.vertical, 60)
    }
}

struct StoryCard: View {
    let article: Article
    var featured = false
    @Environment(NewsStore.self) private var store

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            if featured {
                StoryImage(article: article, height: 216).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            CoverageLabel(coverage: article.coverage)
            HStack(alignment: .top, spacing: 14) {
                Text(article.title)
                    .font(featured ? .system(size: 24, weight: .bold) : .system(size: 18, weight: .semibold))
                    .tracking(-0.6)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if !featured {
                    StoryImage(article: article, height: 78)
                        .frame(width: 78).clipShape(RoundedRectangle(cornerRadius: 5)).accessibilityHidden(true)
                }
            }
            if featured {
                Text(article.summary).font(.subheadline).foregroundStyle(NewsTheme.secondary).lineLimit(3).lineSpacing(3)
            }
            BiasBar(coverage: article.coverage)
            HStack(spacing: 7) {
                Text(article.time)
                Text("·")
                Text("\(article.sources) sources")
                Spacer()
                if store.readIDs.contains(article.id) { Image(systemName: "checkmark.circle").accessibilityLabel("Read") }
                if store.savedIDs.contains(article.id) { Image(systemName: "bookmark.fill").accessibilityLabel("Saved") }
            }
            .font(.caption).foregroundStyle(NewsTheme.secondary)
        }
        .padding(15)
        .liquidGlass(cornerRadius: 14)
        .foregroundStyle(NewsTheme.ink)
        .contentShape(Rectangle())
    }
}

struct ArticleList: View {
    let articles: [Article]
    var firstFeatured = false
    var body: some View {
        LazyVStack(spacing: 12) {
            ForEach(Array(articles.enumerated()), id: \.element.id) { index, article in
                NavigationLink(value: article) {
                    StoryCard(article: article, featured: firstFeatured && index == 0)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("story-\(article.id)")
            }
        }
    }
}

