import SwiftUI

@main
struct PalilogyApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear { AppSettings.applyAppearance() }
        }
        .defaultSize(width: 960, height: 620)

        Settings {
            SettingsView()
        }
    }
}
