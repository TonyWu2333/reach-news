import SwiftUI

// MARK: - 根视图
//
// 三个标签（日报 / 频道 / 我的）。标签栏与导航栏使用系统能力呈现半透明玻璃，
// 内容从其下方滚过；不手写毛玻璃材质。

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.appLocale) private var locale
    @State private var selection: Tab = .briefs

    enum Tab: Hashable {
        case briefs
        case channels
        case me
    }

    var body: some View {
        Group {
            if let env {
                if env.session.isConnected {
                    tabs(env)
                } else {
                    NavigationStack {
                        ConnectionView(session: env.session)
                    }
                }
            } else {
                ProgressView()
            }
        }
        .tint(Palette.ink)
        .task {
            // 启动时若已有凭证，静默验证一次，不弹连接页。
            await env?.session.validateStoredCredentials()
        }
    }

    private func tabs(_ env: AppEnvironment) -> some View {
        TabView(selection: $selection) {
            BriefFeedView()
                .tabItem {
                    Label {
                        Text(L10n.string("tab.briefs", locale: locale))
                    } icon: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                }
                .tag(Tab.briefs)

            ChannelListView()
                .tabItem {
                    Label {
                        Text(L10n.string("tab.channels", locale: locale))
                    } icon: {
                        Image(systemName: "slider.horizontal.below.rectangle")
                    }
                }
                .tag(Tab.channels)

            MeView()
                .tabItem {
                    Label {
                        Text(L10n.string("tab.me", locale: locale))
                    } icon: {
                        Image(systemName: "person.crop.circle")
                    }
                }
                .tag(Tab.me)
        }
        .accessibilityIdentifier("root-tabs")
    }
}
