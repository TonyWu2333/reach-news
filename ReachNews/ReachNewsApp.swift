import SwiftUI

@main
struct ReachNewsApp: App {
    @State private var store = NewsStore()
    @AppStorage("appLanguage") private var appLanguage = "system"

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(\.locale, appLocale)
                .tint(NewsTheme.ink)
                .preferredColorScheme(.light)
        }
    }

    private var appLocale: Locale {
        switch appLanguage {
        case "zh-Hans": Locale(identifier: "zh-Hans")
        case "en": Locale(identifier: "en")
        default: .current
        }
    }
}

