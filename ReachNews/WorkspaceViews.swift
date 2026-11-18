import SwiftUI

private extension String {
    var workspaceTint: Color {
        switch self {
        case "purple": NewsTheme.purple
        case "blue": NewsTheme.left
        case "gold": NewsTheme.gold
        case "coral": NewsTheme.right
        default: NewsTheme.ink
        }
    }
}

struct ExploreView: View {
    @Environment(NewsStore.self) private var store
    @State private var section = "Channels"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SectionHeading(title: "Build your brief", subtitle: "Configure the collectors, channels and events that shape each morning.")
                Picker("Workspace section", selection: $section) {
                    Text("Channels").tag("Channels")
                    Text("Collectors").tag("Collectors")
                    Text("Stories").tag("Stories")
                }.pickerStyle(.segmented)

                if section == "Channels" {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Daily channels").font(.title3.bold())
                        Spacer()
                        Text("4 presets").font(.caption).foregroundStyle(NewsTheme.secondary)
                    }
                    ForEach(store.channels) { channel in
                        NavigationLink { ChannelDetailView(channel: channel) } label: {
                            ChannelRow(channel: channel, showChevron: true)
                        }.buttonStyle(.plain)
                    }
                    NavigationLink { EventsView() } label: {
                        HStack {
                            Image(systemName: "scope").font(.title3)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Track an event").font(.headline)
                                Text("Turn a developing story into its own daily channel.").font(.caption).foregroundStyle(NewsTheme.secondary)
                            }
                            Spacer()
                            Image(systemName: "plus.circle.fill").font(.title3)
                        }.padding(15).background(NewsTheme.ink.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain)
                } else if section == "Collectors" {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Your collectors").font(.title3.bold())
                        Spacer()
                        Text("Private configuration").font(.caption).foregroundStyle(NewsTheme.secondary)
                    }
                    Text("Collectors are attached to your channels and events. The source cache only keeps recent items so agents can deduplicate work.")
                        .font(.caption).foregroundStyle(NewsTheme.secondary).lineSpacing(2)
                    ForEach(store.collectors) { collector in
                        CollectorCard(collector: collector)
                    }
                    Button { } label: {
                        Label("Add a collector", systemImage: "plus")
                            .font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    }.buttonStyle(.borderedProminent).tint(NewsTheme.ink)
                } else {
                    StoryExploreView()
                }
            }
            .padding(18).padding(.bottom, 24).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background(NewsTheme.paper.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }
}

struct ChannelRow: View {
    let channel: BriefingChannel
    var showChevron = false

    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: channel.symbol).font(.headline).foregroundStyle(channel.tint.workspaceTint)
                .frame(width: 40, height: 40).background(channel.tint.workspaceTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(channel.name).font(.headline)
                    if !channel.isEnabled { Tag(text: "PAUSED", color: NewsTheme.secondary) }
                }
                Text(channel.schedule).font(.caption).foregroundStyle(NewsTheme.secondary)
            }
            Spacer(minLength: 0)
            if channel.unreadCount > 0 {
                Text("\(channel.unreadCount)").font(.caption.bold()).foregroundStyle(.white)
                    .frame(width: 25, height: 25).background(NewsTheme.ink, in: Circle())
            }
            if showChevron { Image(systemName: "chevron.right").font(.caption).foregroundStyle(NewsTheme.secondary) }
        }
        .padding(14)
        .background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 14))
        .foregroundStyle(NewsTheme.ink)
    }
}

struct CollectorCard: View {
    let collector: Collector
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: collector.symbol).font(.title3).foregroundStyle(collector.tint.workspaceTint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(collector.name).font(.headline)
                    Text(collector.source).font(.caption).foregroundStyle(NewsTheme.secondary)
                }
                Spacer()
                Tag(text: collector.status.uppercased(), color: collector.tint.workspaceTint)
            }
            HStack {
                Label(collector.cadence, systemImage: "clock")
                Spacer()
                Text("\(collector.itemCount) cached items")
            }.font(.caption).foregroundStyle(NewsTheme.secondary)
            Text("Last run \(collector.lastRun)").font(.caption2).foregroundStyle(NewsTheme.secondary)
        }
        .padding(15).background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct EventRow: View {
    let event: TrackedEvent
    var body: some View {
        HStack(spacing: 13) {
            Image(systemName: event.symbol).font(.headline).foregroundStyle(event.tint.workspaceTint)
                .frame(width: 40, height: 40).background(event.tint.workspaceTint.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title).font(.headline)
                Text("\(event.updates) updates · \(event.lastUpdated)").font(.caption).foregroundStyle(NewsTheme.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(NewsTheme.secondary)
        }.padding(14).background(NewsTheme.card, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(NewsTheme.ink)
    }
}

struct ChannelDetailView: View {
    let channel: BriefingChannel
    @Environment(NewsStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    Image(systemName: channel.symbol).font(.title).foregroundStyle(channel.tint.workspaceTint)
                        .frame(width: 54, height: 54).background(channel.tint.workspaceTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 4) { Text(channel.name).font(NewsTheme.headline(35)); Text(channel.schedule).font(.subheadline).foregroundStyle(NewsTheme.secondary) }
                }
                Text(channel.summary).font(.title3).foregroundStyle(NewsTheme.secondary).lineSpacing(3)
                HStack(spacing: 10) {
                    MetricCard(title: "Collectors", value: "\(channel.collectorIDs.count)", icon: "bolt.fill")
                    MetricCard(title: "Unread", value: "\(channel.unreadCount)", icon: "newspaper")
                }
                Text("Attached collectors").font(NewsTheme.headline(28))
                ForEach(store.collectors.filter { channel.collectorIDs.contains($0.id) }) { collector in CollectorCard(collector: collector) }
                Text("Latest in this channel").font(NewsTheme.headline(28))
                ArticleList(articles: store.articles.filter { $0.category == "Technology" || $0.category == "Business" }.prefix(3).map { $0 }, firstFeatured: true)
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(NewsTheme.paper.ignoresSafeArea()).navigationTitle("Channel").navigationBarTitleDisplayMode(.inline)
    }
}

struct EventsView: View {
    @Environment(NewsStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SectionHeading(title: "Tracked events", subtitle: "Keep an agent watching a developing story and receive a focused daily update.")
                ForEach(store.trackedEvents) { event in NavigationLink { EventDetailView(event: event) } label: { EventRow(event: event) }.buttonStyle(.plain) }
                Button { } label: { Label("Track a new event", systemImage: "plus").frame(maxWidth: .infinity).padding(.vertical, 12) }.buttonStyle(.borderedProminent).tint(NewsTheme.ink)
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.toolbar(.hidden, for: .navigationBar)
    }
}

struct EventDetailView: View {
    let event: TrackedEvent
    @Environment(NewsStore.self) private var store
    @State private var showAsk = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 13) {
                    Image(systemName: event.symbol).font(.title).foregroundStyle(event.tint.workspaceTint)
                        .frame(width: 54, height: 54).background(event.tint.workspaceTint.opacity(0.14), in: Circle())
                    VStack(alignment: .leading, spacing: 4) { Text(event.title).font(NewsTheme.headline(35)); Text("Watching · \(event.lastUpdated)").font(.subheadline).foregroundStyle(NewsTheme.secondary) }
                }
                Text("\"\(event.query)\"").font(.title3).foregroundStyle(NewsTheme.secondary)
                HStack(spacing: 10) { MetricCard(title: "Updates", value: "\(event.updates)", icon: "bell"); MetricCard(title: "Channel", value: event.channelName, icon: "rectangle.3.group") }
                Button { showAsk = true } label: { Label("Ask the agent about this event", systemImage: "sparkles").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14) }.buttonStyle(.borderedProminent).tint(NewsTheme.ink)
                Text("Latest updates").font(NewsTheme.headline(28))
                ArticleList(articles: store.articles.prefix(3).map { $0 }, firstFeatured: true)
            }.padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }.background(NewsTheme.paper.ignoresSafeArea()).navigationTitle("Event").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $showAsk) { AskAgentView(context: event.title) }
    }
}

struct AskAgentView: View {
    let context: String
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var messages: [AIMessage]

    init(context: String) {
        self.context = context
        _messages = State(initialValue: [AIMessage(role: "agent", text: "I’m watching \(context). Ask for a timeline, the latest change, or more context.")])
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(messages) { message in
                            Text(message.text).padding(13).background(message.role == "agent" ? NewsTheme.card : NewsTheme.ink, in: RoundedRectangle(cornerRadius: 14)).foregroundStyle(message.role == "agent" ? NewsTheme.ink : .white).frame(maxWidth: .infinity, alignment: message.role == "agent" ? .leading : .trailing)
                        }
                    }.padding(18)
                }
                HStack(spacing: 8) {
                    TextField("Ask about this story…", text: $prompt).textFieldStyle(.roundedBorder)
                    Button { send() } label: { Image(systemName: "arrow.up.circle.fill").font(.title2) }.disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }.padding(12).background(.thinMaterial)
            }.navigationTitle("Ask the agent").navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
    private func send() {
        let value = prompt.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }
        messages.append(AIMessage(role: "user", text: value)); prompt = ""
        messages.append(AIMessage(role: "agent", text: "Mock answer: I found 6 cached updates related to \(context). The latest reporting agrees on the immediate change, while the long-term impact remains contested."))
    }
}
