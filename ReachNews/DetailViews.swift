import SwiftUI

struct ArticleDetailView: View {
    let article: Article
    @Environment(NewsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var analysisShown = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                StoryImage(article: article, height: 230)
                HStack {
                    Text(article.category).font(.subheadline.weight(.medium)).foregroundStyle(NewsTheme.secondary)
                    Spacer()
                    Text(article.time).font(.subheadline).foregroundStyle(NewsTheme.secondary)
                }
                Text(article.title).font(NewsTheme.headline(42)).tracking(-0.8).fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 18) {
                    Button { store.toggleSave(article) } label: {
                        Label(store.savedIDs.contains(article.id) ? "Saved" : "Save", systemImage: store.savedIDs.contains(article.id) ? "bookmark.fill" : "bookmark")
                    }
                    ShareLink(item: article.title) { Label("Share", systemImage: "square.and.arrow.up") }
                }.font(.subheadline.weight(.semibold))
                Text(article.summary).font(.title3).foregroundStyle(NewsTheme.secondary).lineSpacing(4)

                VStack(alignment: .leading, spacing: 15) {
                    Text("Coverage").font(.headline)
                    BiasBar(coverage: article.coverage, showLabels: true)
                }.padding(18).background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 14))
                HStack(spacing: 12) {
                    MetricCard(title: "Coverage", value: "\(article.sources) sources", icon: "newspaper")
                    MetricCard(title: "Bias", value: article.coverage.label.replacingOccurrences(of: " coverage", with: ""), icon: "chart.bar.xaxis")
                }
                HStack(spacing: 12) {
                    MetricCard(title: "Factuality", value: "High", icon: "checkmark.seal")
                    MetricCard(title: "Ownership", value: "Diverse", icon: "circle.grid.2x2")
                }
                Button { withAnimation(.easeInOut) { analysisShown.toggle() } } label: {
                    HStack { Text(analysisShown ? "Hide analysis" : "Full analysis").font(.headline).underline(); Spacer(); Image(systemName: analysisShown ? "arrow.up.right" : "arrow.right") }
                }.buttonStyle(.plain)
                if analysisShown { AnalysisView(article: article) }
                Text("Where sources agree").font(NewsTheme.headline(31))
                Text(article.agreement).font(.body).lineSpacing(4)
                Text("Where sources disagree").font(NewsTheme.headline(31))
                Text(article.disagreement).font(.body).lineSpacing(4)
                if !article.perspectives.isEmpty {
                    Text("Different perspectives").font(NewsTheme.headline(31))
                    ForEach(article.perspectives) { perspective in PerspectiveCard(perspective: perspective) }
                }
            }
            .padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(.white)
        .navigationTitle("Story").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.toggleSave(article) } label: { Image(systemName: store.savedIDs.contains(article.id) ? "bookmark.fill" : "bookmark") }
            }
        }
        .onAppear { store.markRead(article) }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text(title).font(.subheadline).foregroundStyle(NewsTheme.secondary); Spacer(); Image(systemName: icon).foregroundStyle(NewsTheme.secondary) }
            Text(value).font(.subheadline.weight(.medium)).lineLimit(1, reservesSpace: true)
        }.padding(14).frame(maxWidth: .infinity, alignment: .leading).background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct AnalysisView: View {
    let article: Article
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("A closer look").font(.headline)
            HStack(spacing: 12) {
                AnalysisRing(value: article.coverage.left, color: NewsTheme.left, label: "Left")
                AnalysisRing(value: article.coverage.center, color: NewsTheme.center, label: "Center")
                AnalysisRing(value: article.coverage.right, color: NewsTheme.right, label: "Right")
            }
            Text("The distribution shows how many sources represent each part of the political spectrum. Use the mix as a starting point, then read the original sources for the complete picture.").font(.subheadline).foregroundStyle(NewsTheme.secondary).lineSpacing(3)
        }.padding(18).background(NewsTheme.paper, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct AnalysisRing: View {
    let value: Int; let color: Color; let label: String
    var body: some View {
        VStack(spacing: 7) {
            ZStack {
                Circle().stroke(color.opacity(0.16), lineWidth: 8)
                Circle().trim(from: 0, to: CGFloat(value) / 100).stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(value)%").font(.caption.bold())
            }.frame(width: 64, height: 64)
            Text(label).font(.caption).foregroundStyle(NewsTheme.secondary)
        }.frame(maxWidth: .infinity)
    }
}

struct PerspectiveCard: View {
    let perspective: Perspective
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(perspective.side).font(.subheadline.weight(.semibold)).foregroundStyle(NewsTheme.secondary)
            Text(perspective.title).font(.title3.bold())
            Text(perspective.summary).font(.body).foregroundStyle(NewsTheme.secondary)
            Text("“\(perspective.quote)”").font(.title3.bold()).multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.top, 8)
            Text(perspective.attribution).font(.caption).foregroundStyle(NewsTheme.secondary).frame(maxWidth: .infinity, alignment: .center)
        }.padding(20).background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct BlindspotsView: View {
    @Environment(NewsStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "The Blindspots", subtitle: "Stories receiving coverage from only one side of the political spectrum.")
                if store.blindspots.isEmpty {
                    EmptyState(symbol: "checkmark.circle", title: "No blindspots today", message: "We’ll show stories here when coverage is concentrated on one side.")
                } else { ArticleList(articles: store.blindspots, firstFeatured: true) }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.toolbar(.hidden, for: .navigationBar)
    }
}

struct Last24View: View {
    @Environment(NewsStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("The Last 24").font(NewsTheme.headline(48))
                Text("updated 7h ago  •  4 minutes read").font(.subheadline).foregroundStyle(NewsTheme.secondary)
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(store.articles.prefix(4).enumerated()), id: \.element.id) { index, article in
                        NavigationLink(value: article) {
                            HStack(alignment: .top, spacing: 14) {
                                Text("\(index + 1)").font(.title2.bold()).frame(width: 25)
                                Text(article.title).font(.title3.bold()).multilineTextAlignment(.leading)
                            }
                        }.buttonStyle(.plain)
                    }
                }.padding(.vertical, 10)
                Divider()
                ForEach(Array(store.articles.prefix(4).enumerated()), id: \.element.id) { index, article in
                    VStack(alignment: .leading, spacing: 12) {
                        Text("\(index + 1)").font(.headline).padding(9).background(Circle().fill(NewsTheme.ink)).foregroundStyle(.white)
                        Text(article.title).font(.title2.bold())
                        StoryImage(article: article, height: 210).clipShape(RoundedRectangle(cornerRadius: 10))
                    }.padding(.vertical, 8)
                }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.toolbar(.hidden, for: .navigationBar)
    }
}

