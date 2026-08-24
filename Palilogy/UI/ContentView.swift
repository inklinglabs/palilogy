import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        NavigationSplitView {
            List(selection: sidebarSelection) {
                Section("Jobs") {
                    ForEach([AppState.Scope.all, .enabled, .disabled]) { scope in
                        Label(scope.title, systemImage: scope.systemImage).tag(scope)
                    }
                }
                Section("Legacy") {
                    Label(AppState.Scope.cron.title, systemImage: AppState.Scope.cron.systemImage)
                        .tag(AppState.Scope.cron)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)
        } content: {
            JobListView()
                .navigationSplitViewColumnWidth(min: 260, ideal: 320)
        } detail: {
            JobDetailView()
        }
        .task { await state.refresh() }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(5))
                await state.refreshStatuses()
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await state.refresh() }
                }
                .help("Reload jobs and cron entries")
            }
            ToolbarItem(placement: .primaryAction) {
                Button("New Job", systemImage: "plus") {
                    state.presentNewJob()
                }
                .help("Schedule a new job")
            }
        }
        .sheet(
            isPresented: Binding(
                get: { state.editorDraft != nil },
                set: { if !$0 { state.editorDraft = nil } }
            )
        ) {
            if let draft = state.editorDraft {
                JobEditorView(draft: draft)
            }
        }
        .alert(
            "Something Went Wrong",
            isPresented: Binding(
                get: { state.lastError != nil },
                set: { if !$0 { state.lastError = nil } }
            )
        ) {
            Button("OK") { state.lastError = nil }
        } message: {
            Text(state.lastError ?? "")
        }
    }

    private var sidebarSelection: Binding<AppState.Scope?> {
        Binding(
            get: { state.scope },
            set: { state.scope = $0 ?? .all }
        )
    }
}

#Preview {
    ContentView().environment(AppState())
}
