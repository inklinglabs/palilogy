import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            List {
                Section("Jobs") {
                    Label("All", systemImage: "clock")
                    Label("Enabled", systemImage: "play.circle")
                    Label("Disabled", systemImage: "pause.circle")
                }
                Section("Legacy") {
                    Label("Cron", systemImage: "terminal")
                }
            }
            .listStyle(.sidebar)
        } content: {
            ContentUnavailableView(
                "No Jobs Yet",
                systemImage: "clock.badge.questionmark",
                description: Text("Jobs you schedule will appear here.")
            )
        } detail: {
            ContentUnavailableView(
                "Nothing Selected",
                systemImage: "sidebar.right",
                description: Text("Select a job to see its details.")
            )
        }
    }
}

#Preview {
    ContentView()
}
