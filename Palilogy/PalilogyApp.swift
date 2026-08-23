import SwiftUI

@main
struct PalilogyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 960, height: 620)
    }
}
