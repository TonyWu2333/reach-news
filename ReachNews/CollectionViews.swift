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
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false
    @AppStorage("appLanguage") private var appLanguage = "system"
    var body: some View {
        List {
                Section("Your account") {
                    Label("Reach News member", systemImage: "person.crop.circle.fill")
                    Label("Personalized briefing", systemImage: "sparkles")
                }
                Section("Reading") {
                    NavigationLink { TopicManagerView() } label: { Label("Manage topics", systemImage: "list.bullet") }
                    Button { confirmReset = true } label: { Label("Clear reading history", systemImage: "arrow.counterclockwise") }.foregroundStyle(NewsTheme.ink)
                }
                Section("Language") {
                    Picker("App language", selection: $appLanguage) {
                        Text("System").tag("system")
                        Text("English").tag("en")
                        Text("中文").tag("zh-Hans")
                    }
                }
                Section("About") {
                    LabeledContent("Version", value: "0.0.1 (10008)")
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
