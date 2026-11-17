import SwiftUI

enum AppTab: String, CaseIterable {
    case briefing = "Briefing"
    case explore = "Explore"
    case following = "Following"
    var symbol: String {
        switch self {
        case .briefing: "book.pages.fill"
        case .explore: "magnifyingglass"
        case .following: "bookmark.fill"
        }
    }
}

struct RootView: View {
    @State private var selectedTab: AppTab = .briefing
    @State private var glass = LiquidGlassSettings()

    init() {
        if let preview = ProcessInfo.processInfo.environment["REACH_PREVIEW_TAB"] ?? UserDefaults.standard.string(forKey: "REACH_PREVIEW_TAB") {
            switch preview.lowercased() {
            case "explore": _selectedTab = State(initialValue: .explore)
            case "following": _selectedTab = State(initialValue: .following)
            default: _selectedTab = State(initialValue: .briefing)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            currentTab
            FloatingTabBar(
                selection: $selectedTab,
                previewDragProgress: previewDragProgress
            )
                .padding(.horizontal, 18)
                .padding(.bottom, 8)
        }
        .environment(glass)
        .background(NewsTheme.paper.ignoresSafeArea())
        .tint(NewsTheme.ink)
    }

    private var previewDragProgress: CGFloat? {
        let raw = ProcessInfo.processInfo.environment["REACH_PREVIEW_DRAG"] ?? UserDefaults.standard.string(forKey: "REACH_PREVIEW_DRAG")
        guard let raw, let value = Double(raw) else { return nil }
        return CGFloat(min(max(value, 0), 1))
    }

    @ViewBuilder
    private var currentTab: some View {
        switch selectedTab {
        case .briefing:
            NavigationStack {
                BriefingView()
                    .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
                    .navigationDestination(for: NewsCollection.self) { CollectionDetailView(collection: $0) }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        case .explore:
            NavigationStack {
                ExploreView()
                    .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
                    .navigationDestination(for: NewsCollection.self) { CollectionDetailView(collection: $0) }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        case .following:
            NavigationStack {
                FollowingView()
                    .navigationDestination(for: Article.self) { ArticleDetailView(article: $0) }
                    .navigationDestination(for: NewsCollection.self) { CollectionDetailView(collection: $0) }
                    .toolbarBackground(.hidden, for: .navigationBar)
            }
        }
    }
}

struct FloatingTabBar: View {
    @Binding var selection: AppTab
    var previewDragProgress: CGFloat? = nil
    @State private var dragX: CGFloat?
    @State private var isDragging = false
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        let tabs = AppTab.allCases
        return ZStack {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.18))
                }
                .overlay {
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.55), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)

            GeometryReader { proxy in
                let width = proxy.size.width
                let effectiveDrag = previewDragProgress.map { $0 * width } ?? dragX
                let indicatorX = effectiveDrag ?? (width * (CGFloat(tabs.firstIndex(of: selection) ?? 0) + 0.5) / CGFloat(tabs.count))
                let dragging = isDragging || previewDragProgress != nil

                ZStack {
                    LiquidDropIndicator(
                        progress: indicatorX,
                        width: width,
                        isDragging: dragging
                    )

                    HStack(spacing: 0) {
                        ForEach(tabs, id: \.self) { tab in
                            Button {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.84)) { selection = tab }
                            } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: tab.symbol)
                                        .font(.system(size: 15, weight: .semibold))
                                    if selection == tab && !dragging {
                                        Text(tab.rawValue)
                                            .font(.caption.weight(.bold))
                                    }
                                }
                                .foregroundStyle(selection == tab ? NewsTheme.ink : NewsTheme.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tab.rawValue)
                            .accessibilityAddTraits(selection == tab ? .isSelected : [])
                        }
                    }
                }
                .onAppear { contentWidth = width }
                .onChange(of: width) { _, newValue in contentWidth = newValue }
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 58)
        .frame(maxWidth: 430)
        .clipShape(Capsule(style: .continuous))
        .contentShape(Capsule())
        .highPriorityGesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    let width = max(contentWidth, 1)
                    let x = max(0, min(width, value.location.x))
                    dragX = x
                    isDragging = true
                    let segment = max(0, min(tabs.count - 1, Int(x / width * CGFloat(tabs.count))))
                    let tab = tabs[segment]
                    if selection != tab {
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.88)) {
                            selection = tab
                        }
                    }
                }
                .onEnded { _ in
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.88)) {
                        dragX = nil
                        isDragging = false
                    }
                }
        )
    }
}

struct LiquidDropIndicator: View {
    let progress: CGFloat
    let width: CGFloat
    let isDragging: Bool

    var body: some View {
        let segment = width / 3
        ZStack {
            Capsule()
                .fill(.white.opacity(isDragging ? 0.34 : 0.22))
                .overlay { Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1) }
                .frame(width: segment - 14, height: 40)
            Ellipse()
                .fill(.white.opacity(0.55))
                .frame(width: 28, height: 10)
                .blur(radius: 4)
                .offset(y: -12)
        }
        .frame(width: segment, height: 48)
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        // GeometryReader places children at the top-leading origin, so center by segment/2.
        .offset(x: progress - segment / 2)
        .allowsHitTesting(false)
    }
}

struct BriefingView: View {
    @Environment(NewsStore.self) private var store
    @State private var category = "Top stories"
    @State private var showSettings = false
    private let categories = ["Top stories", "World", "United States", "Politics", "Environment"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                            .font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(NewsTheme.secondary)
                        Text("Your daily perspective.").font(NewsTheme.headline(39)).tracking(-0.4)
                    }
                    Spacer(minLength: 8)
                    Button { showSettings = true } label: { RoundIcon(symbol: "person.crop.circle") }
                        .accessibilityLabel("Settings").accessibilityIdentifier("settings")
                }

                NavigationLink { Last24View() } label: { DailyBriefCard() }
                    .buttonStyle(.plain).accessibilityIdentifier("last24")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(categories, id: \.self) { item in
                            Button { withAnimation(.easeInOut(duration: 0.2)) { category = item } } label: {
                                VStack(spacing: 10) {
                                    Text(item).font(.subheadline.weight(category == item ? .bold : .regular))
                                        .foregroundStyle(category == item ? NewsTheme.ink : NewsTheme.secondary)
                                    Rectangle().fill(category == item ? NewsTheme.ink : .clear).frame(height: 2)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(category == item ? .isSelected : [])
                        }
                    }
                }
                .overlay(alignment: .bottom) { NewsTheme.line.frame(height: 0.5) }

                if let error = store.loadError {
                    EmptyState(symbol: "newspaper", title: "Briefing unavailable", message: error)
                } else {
                    ArticleList(articles: category == "Top stories" ? store.articles : store.search("", topic: category), firstFeatured: true)
                }

                NavigationLink { BlindspotsView() } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("The Blindspots").font(NewsTheme.headline(34))
                            Text("See what the other side is missing.").font(.subheadline)
                        }
                        Spacer()
                        Image(systemName: "circle.lefthalf.filled").font(.system(size: 35))
                    }
                    .padding(20).background(NewsTheme.gold.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain).accessibilityIdentifier("blindspots-link")

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("A wider perspective").font(.title3.bold())
                        Spacer()
                        NavigationLink("See all") { CollectionsView() }.font(.caption).underline()
                    }
                    NavigationLink(value: NewsCollection.divergent) {
                        CollectionCard(collection: .divergent, compact: true)
                    }.buttonStyle(.plain)
                }
                Text("More context. A clearer picture.").font(.caption).foregroundStyle(NewsTheme.secondary)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .padding(.horizontal, 18).padding(.top, 10).padding(.bottom, 110)
            .frame(maxWidth: 700)
            .frame(maxWidth: .infinity)
        }
        .background(NewsTheme.paper.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 7) {
                    Image(systemName: "globe.americas.fill").font(.system(size: 17))
                    Text("REACH").font(.system(size: 20, weight: .black)).tracking(3)
                    Text("NEWS").font(.system(size: 11, weight: .medium)).tracking(2)
                }.accessibilityElement(children: .combine)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }
}

struct DailyBriefCard: View {
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Circle().fill(NewsTheme.ink).frame(width: 5, height: 5)
                    Text("THE BIG PICTURE").font(.system(size: 9, weight: .bold)).tracking(1.5)
                }
                Text("The Last 24").font(NewsTheme.headline(38))
                Text("Your world, in a 4-minute read.").font(.caption).foregroundStyle(NewsTheme.secondary)
            }
            Spacer(minLength: 0)
            Image(systemName: "newspaper").font(.system(size: 41, weight: .ultraLight)).rotationEffect(.degrees(-8))
            Image(systemName: "arrow.up.right").font(.subheadline)
        }
        .padding(18).liquidGlass(cornerRadius: 14)
        .foregroundStyle(NewsTheme.ink)
    }
}

struct ExploreView: View {
    @Environment(NewsStore.self) private var store
    @State private var query = ""
    @State private var selectedTopic: String?

    private var results: [Article] { store.search(query, topic: selectedTopic) }
    private var isFiltering: Bool { !query.isEmpty || selectedTopic != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SectionHeading(title: "Explore", subtitle: "Go beyond your usual headlines.")
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(NewsTheme.secondary)
                    TextField("Search stories and topics", text: $query)
                        .font(.subheadline).autocorrectionDisabled().submitLabel(.search)
                        .accessibilityIdentifier("search-field")
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(NewsTheme.secondary) }
                            .accessibilityLabel("Clear search")
                    }
                }
                .padding(14).background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 10))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Topics to explore").font(.headline)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 9) {
                        ForEach(NewsStore.topics, id: \.self) { topic in
                            Button {
                                selectedTopic = selectedTopic == topic ? nil : topic
                            } label: {
                                HStack {
                                    Text(topic).font(.subheadline.weight(.medium))
                                    Spacer(minLength: 0)
                                    Image(systemName: selectedTopic == topic ? "checkmark" : "arrow.up.right").font(.caption)
                                }
                                .padding(13)
                                .foregroundStyle(selectedTopic == topic ? .white : NewsTheme.ink)
                                .background(selectedTopic == topic ? NewsTheme.ink : NewsTheme.paper, in: RoundedRectangle(cornerRadius: 7))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                if isFiltering {
                    HStack {
                        Text("\(results.count) \(results.count == 1 ? "story" : "stories")").font(.headline)
                        Spacer()
                        Button("Reset") { query = ""; selectedTopic = nil }.font(.subheadline).underline()
                    }
                    if results.isEmpty {
                        EmptyState(symbol: "magnifyingglass", title: "No stories found", message: "Try a different headline, keyword or topic.")
                    } else {
                        ArticleList(articles: results)
                    }
                } else {
                    NavigationLink { BlindspotsView() } label: {
                        HStack(spacing: 15) {
                            Image(systemName: "circle.lefthalf.filled").font(.system(size: 32))
                            VStack(alignment: .leading, spacing: 4) {
                                Text("The Blindspots").font(NewsTheme.headline(30))
                                Text("Discover the stories you’re missing.").font(.caption).foregroundStyle(NewsTheme.secondary)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right").font(.caption)
                        }.padding(18).background(NewsTheme.gold.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain).accessibilityIdentifier("blindspots-link")

                    HStack(alignment: .firstTextBaseline) {
                        SectionHeading(title: "Collections")
                        NavigationLink("View all") { CollectionsView() }.font(.caption).underline().fixedSize()
                    }
                    ForEach(NewsCollection.allCases) { collection in
                        NavigationLink(value: collection) { CollectionCard(collection: collection) }
                            .buttonStyle(.plain)
                    }
                }
            }
            .padding(18).padding(.bottom, 110).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(NewsTheme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct FollowingView: View {
    @Environment(NewsStore.self) private var store
    @State private var section = "My feed"
    @State private var manageTopics = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SectionHeading(title: "Following", subtitle: "Your interests. A broader point of view.")
                Picker("Following section", selection: $section) {
                    Text("My feed").tag("My feed")
                    Text("Saved").tag("Saved")
                }.pickerStyle(.segmented).accessibilityIdentifier("following-picker")
                if section == "Saved" {
                    if store.savedArticles.isEmpty {
                        EmptyState(symbol: "bookmark", title: "Keep a story for later", message: "Tap the bookmark on any story. You’ll find it here whenever you’re ready.")
                    } else {
                        Text("\(store.savedArticles.count) saved stories").font(.subheadline).foregroundStyle(NewsTheme.secondary)
                        ArticleList(articles: store.savedArticles)
                    }
                } else {
                    HStack {
                        Text("Your topics").font(.headline)
                        Spacer()
                        Button("Manage") { manageTopics = true }.font(.subheadline).underline()
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(store.followedTopics.sorted(), id: \.self) { topic in
                                Tag(text: topic)
                            }
                        }
                    }
                    if !store.followedCollections.isEmpty {
                        ForEach(NewsCollection.allCases.filter { store.followedCollections.contains($0.rawValue) }) { collection in
                            NavigationLink(value: collection) { CollectionCard(collection: collection, compact: true) }
                                .buttonStyle(.plain)
                        }
                    }
                    if store.followingArticles.isEmpty {
                        EmptyState(symbol: "globe", title: "Make room for your interests", message: "Choose a topic to start building your personal briefing.")
                        Button("Choose topics") { manageTopics = true }.buttonStyle(.bordered).frame(maxWidth: .infinity)
                    } else {
                        ArticleList(articles: store.followingArticles, firstFeatured: true)
                    }
                }
            }
            .padding(18).padding(.bottom, 110).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(NewsTheme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $manageTopics) { TopicManagerView() }
    }
}

struct TopicManagerView: View {
    @Environment(NewsStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Build your perspective") {
                    ForEach(NewsStore.topics, id: \.self) { topic in
                        Button { store.toggleTopic(topic) } label: {
                            HStack {
                                Text(topic)
                                Spacer()
                                Image(systemName: store.followedTopics.contains(topic) ? "checkmark.circle.fill" : "plus.circle")
                            }.foregroundStyle(NewsTheme.ink).padding(.vertical, 8)
                        }
                        .accessibilityLabel("\(store.followedTopics.contains(topic) ? "Unfollow" : "Follow") \(topic)")
                    }
                }
            }
            .navigationTitle("Your topics").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

