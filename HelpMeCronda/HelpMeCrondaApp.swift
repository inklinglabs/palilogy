import SwiftUI

@main
struct HelpMeCrondaApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
        }
        .defaultSize(width: 960, height: 620)
    }
}
