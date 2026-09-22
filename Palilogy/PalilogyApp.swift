import SwiftUI

@main
struct PalilogyApp: App {
    @State private var appState = DemoMode.makeAppState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .onAppear {
                    AppSettings.applyAppearance()
                    #if DEBUG
                    DebugSnapshots.runIfRequested(appState: appState)
                    #endif
                }
        }
        .defaultSize(width: 960, height: 620)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Palilogy") {
                    AboutWindowController.shared.show()
                }
                Button("Check for Updates\u{2026}") {
                    UpdaterManager.shared.checkForUpdates()
                }
                .disabled(!UpdaterManager.shared.isConfigured)
            }
        }

        Settings {
            SettingsView()
        }
    }
}
