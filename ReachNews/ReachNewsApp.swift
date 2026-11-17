import SwiftUI

@main
struct ReachNewsApp: App {
    @State private var store = NewsStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(NewsTheme.ink)
                .preferredColorScheme(.light)
        }
    }
}

