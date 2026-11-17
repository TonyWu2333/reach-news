import SwiftUI
import Foundation

struct CollectionsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Collections", subtitle: "Discover stories through curated perspectives.")
                ForEach(NewsCollection.allCases) { collection in
                    NavigationLink(value: collection) { CollectionCard(collection: collection) }.buttonStyle(.plain)
                }
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.toolbar(.hidden, for: .navigationBar)
    }
}

struct CollectionCard: View {
    let collection: NewsCollection
    var compact = false
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [NewsTheme.collection(collection), NewsTheme.collection(collection).opacity(0.48)], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(alignment: .leading, spacing: compact ? 5 : 10) {
                HStack {
                    Tag(text: "COLLECTION", color: .white, filled: true)
                    Spacer()
                    Image(systemName: "plus").font(.headline).foregroundStyle(.white).frame(width: 30, height: 30).background(.black.opacity(0.22), in: Circle())
                }
                Spacer(minLength: compact ? 5 : 12)
                Image(systemName: collection.symbol).font(.system(size: compact ? 34 : 46, weight: .bold)).foregroundStyle(.white.opacity(0.88))
                Text(collection.rawValue).font(NewsTheme.headline(compact ? 27 : 35)).foregroundStyle(.white)
                Text(collection.subtitle).font(.subheadline).foregroundStyle(.white.opacity(0.9)).lineLimit(compact ? 1 : 2)
            }
            .padding(compact ? 16 : 20)
        }
        .frame(height: compact ? 155 : 205)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct CollectionDetailView: View {
    let collection: NewsCollection
    @Environment(NewsStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CollectionCard(collection: collection)
                HStack {
                    Text("\(collection.articles(from: store.articles).count) stories").font(.subheadline).foregroundStyle(NewsTheme.secondary)
                    Spacer()
                    Button(store.followedCollections.contains(collection.rawValue) ? "Following" : "Follow") { store.toggleCollection(collection) }.buttonStyle(.borderedProminent).tint(NewsTheme.ink)
                }
                ArticleList(articles: collection.articles(from: store.articles), firstFeatured: true)
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.toolbar(.hidden, for: .navigationBar)
    }
}

struct SettingsView: View {
    @Environment(NewsStore.self) private var store
    @Environment(LiquidGlassSettings.self) private var glass
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    var body: some View {
        @Bindable var glass = glass
        NavigationStack {
            List {
                Section("Your account") {
                    Label("Reach News member", systemImage: "person.crop.circle.fill")
                    Label("Personalized briefing", systemImage: "sparkles")
                }
                Section("Reading") {
                    NavigationLink { TopicManagerView() } label: { Label("Manage topics", systemImage: "list.bullet") }
                    Button { confirmReset = true } label: { Label("Clear reading history", systemImage: "arrow.counterclockwise") }.foregroundStyle(NewsTheme.ink)
                }
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Liquid glass", systemImage: "circle.lefthalf.filled")
                            Spacer()
                            Button("Reset") { glass.reset() }.font(.caption).underline()
                        }
                        Text("Tune the floating navigation and story cards.").font(.caption).foregroundStyle(NewsTheme.secondary)
                        GlassSlider(title: "Opacity", value: $glass.opacity, range: 0.25...1, valueFormat: "%.2f")
                        GlassSlider(title: "Blur shadow", value: $glass.blur, range: 4...34, valueFormat: "%.0f")
                        GlassSlider(title: "Corner radius", value: $glass.cornerRadius, range: 14...38, valueFormat: "%.0f")
                        GlassSlider(title: "Tint", value: $glass.tint, range: 0...0.28, valueFormat: "%.2f")
                    }
                    .padding(.vertical, 6)
                } header: {
                    Text("Appearance")
                }
                Section("About") {
                    LabeledContent("Version", value: "0.0.1 (10006)")
                    Text("Reach News helps you compare coverage, see blindspots and read across the spectrum.").foregroundStyle(NewsTheme.secondary)
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .confirmationDialog("Clear your reading history?", isPresented: $confirmReset, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { store.resetReadingHistory() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }
}

struct GlassSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let valueFormat: String

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.caption)
                Spacer()
                Text(String(format: valueFormat, value)).font(.caption.monospacedDigit()).foregroundStyle(NewsTheme.secondary)
            }
            Slider(value: $value, in: range)
        }
    }
}

