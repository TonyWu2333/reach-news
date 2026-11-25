import SwiftUI

// MARK: - 我的
//
// 收藏（仅本机）+ 偏好 + 连接信息。

struct MeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.appLocale) private var locale

    var body: some View {
        NavigationStack {
            content(env)
            .background(Palette.canvas)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavTitle(text: L10n.string("tab.me", locale: locale))
                }
            }
            .navigationDestination(for: MeDestination.self) { destination in
                switch destination {
                case .saved:
                    SavedBriefsView(store: env.feed, saved: env.saved)
                case .preferences:
                    PreferencesView(session: env.session, preferences: env.preferences)
                case .account:
                    AccountDetailView(session: env.session)
                }
            }
        }
    }

    private func content(_ env: AppEnvironment) -> some View {
        List {
            // 整张账号卡片点进个人页；连接信息不再单列入口。
            NavigationLink(value: MeDestination.account) {
                AccountHeaderView(profile: env.profile)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .listRowInsets(EdgeInsets(top: Space.s, leading: Space.l, bottom: Space.s, trailing: Space.l))
            .listRowBackground(Palette.surface)
            .accessibilityIdentifier("me-account-card")

            Section {
                NavigationLink(value: MeDestination.saved) {
                    Label {
                        Text(L10n.string("me.saved", locale: locale))
                    } icon: {
                        Image(systemName: "bookmark")
                    }
                    .badge(env.saved.savedIDs.count)
                }
                .accessibilityIdentifier("me-saved")

                NavigationLink(value: MeDestination.preferences) {
                    Label {
                        Text(L10n.string("me.preferences", locale: locale))
                    } icon: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
                .accessibilityIdentifier("me-preferences")

            }
            .listRowBackground(Palette.surface)
        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .accessibilityIdentifier("me-list")
    }
}

enum MeDestination: Hashable {
    case saved
    case preferences
    /// 账号卡片点进去的个人页：资料、头像、密码与退出登录都在这里。
    case account
}

// MARK: - 收藏列表

struct SavedBriefsView: View {
    let store: BriefFeedStore
    let saved: SavedStore
    @Environment(\.appLocale) private var locale
    @Environment(AppEnvironment.self) private var env

    private var savedBriefs: [Brief] {
        store.briefs
            .filter { saved.savedIDs.contains($0.id) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        Group {
            if savedBriefs.isEmpty {
                MessageStateView(
                    title: L10n.string("me.saved.empty.title", locale: locale),
                    message: L10n.string("me.saved.empty.message", locale: locale),
                    kind: .empty
                )
            } else {
                List {
                    ForEach(savedBriefs) { brief in
                        NavigationLink(value: brief) {
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(brief.title)
                                    .font(TypeFace.heading(14.5))
                                    .foregroundStyle(Palette.ink)
                                    .lineLimit(2)
                                HStack(spacing: 7) {
                                    ChannelDot(channelID: brief.channelID, colorIndex: env.channelColors.colorIndex(for: brief.channelID))
                                    Text(store.displayName(for: brief))
                                        .font(TypeFace.label(11))
                                        .foregroundStyle(Palette.inkSecondary)
                                    DotSeparator()
                                    MetaLine(text: DisplayTime.monthDayTime(brief.createdAt, locale: locale))
                                }
                            }
                            .padding(.vertical, Space.xxs)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                saved.toggle(brief.id)
                            } label: {
                                Label(L10n.string("me.saved.remove", locale: locale), systemImage: "bookmark.slash")
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Palette.canvas)
            }
        }
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavTitle(text: L10n.string("me.saved", locale: locale))
            }
        }
        .navigationDestination(for: Brief.self) { brief in
            BriefDetailView(brief: brief, store: env.makeDetailStore(brief: brief))
        }
        .accessibilityIdentifier("saved-list")
    }
}

// MARK: - 偏好

struct PreferencesView: View {
    let session: SessionStore
    let preferences: PreferencesStoring
    @Environment(\.appLocale) private var locale

    var body: some View {
        List {
            Section {
                Picker(selection: Binding(
                    get: { LanguagePreference(rawValue: preferences.languagePreference) ?? .system },
                    set: { preferences.languagePreference = $0.rawValue }
                )) {
                    ForEach(LanguagePreference.allCases) { option in
                        Text(L10n.string(option.labelKey, locale: locale))
                            .tag(option)
                    }
                } label: {
                    Text(L10n.string("preferences.language", locale: locale))
                }
                .accessibilityIdentifier("preferences-language")
            } header: {
                Text(L10n.string("preferences.language.heading", locale: locale))
            }
            .listRowBackground(Palette.surface)

        }
        .scrollContentBackground(.hidden)
        .background(Palette.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavTitle(text: L10n.string("me.preferences", locale: locale))
            }
        }
    }
}
