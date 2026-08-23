import SwiftUI

struct JobDetailView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        if let file = state.selectedAgent {
            AgentDetailView(file: file)
        } else if let entry = state.selectedCronEntry {
            CronDetailView(entry: entry)
        } else {
            ContentUnavailableView(
                "Nothing Selected",
                systemImage: "sidebar.right",
                description: Text("Select a job to see its details.")
            )
        }
    }
}

struct AgentDetailView: View {
    @Environment(AppState.self) private var state
    var file: AgentFile
    @State private var confirmingDelete = false

    private var isEnabled: Bool { state.isEnabled(file) }
    private var status: JobStatus? { state.statuses[file.agent.label] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(file.agent.displayName)
                        .font(.title2.weight(.semibold))
                        .textSelection(.enabled)
                    if file.agent.palilogyName != nil {
                        Text(file.agent.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    if !file.agent.isManaged {
                        Text("Installed by another app. It can be turned on or off or deleted, but not edited here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 12) {
                    if file.agent.isManaged {
                        Button("Edit") {
                            state.presentEdit(file)
                        }
                    }
                    Button(isEnabled ? "Disable" : "Enable") {
                        Task { await state.toggle(file) }
                    }
                    Button("Run Now") {
                        Task { await state.runNow(file) }
                    }
                    .disabled(!isEnabled)
                    .help(isEnabled ? "Run this job immediately" : "Enable the job to run it")
                    Button("Delete", role: .destructive) {
                        confirmingDelete = true
                    }
                }

                field("Status") {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isEnabled ? Color.green : Color.secondary.opacity(0.4))
                            .frame(width: 8, height: 8)
                        Text(statusText)
                    }
                }
                field("Command") {
                    Text(file.agent.displayCommand)
                        .font(.system(size: 13, design: .monospaced))
                        .textSelection(.enabled)
                }
                field("Schedule") {
                    Text(file.agent.schedule?.displayText ?? "Runs on demand")
                }
                field("File") {
                    Text(file.url.path)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                LogView(agent: file.agent)
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .confirmationDialog(
            "Delete this job?",
            isPresented: $confirmingDelete
        ) {
            Button("Delete \(file.agent.label)", role: .destructive) {
                Task { await state.delete(file) }
            }
        } message: {
            Text("This removes \(file.url.path). The job will not run again.")
        }
    }

    private var statusText: String {
        guard isEnabled else { return "Not loaded" }
        var parts = ["Loaded"]
        if let pid = status?.pid { parts.append("running (pid \(pid))") }
        if let code = status?.lastExitCode {
            parts.append(code == 0 ? "last run succeeded" : "last run failed (exit \(code))")
        }
        return parts.joined(separator: ", ")
    }

    @ViewBuilder
    private func field(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

struct CronDetailView: View {
    @Environment(AppState.self) private var state
    var entry: CronEntry
    @State private var confirmingConvert = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.command)
                        .font(.title3.weight(.semibold))
                        .textSelection(.enabled)
                    Text("From your crontab.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    if state.isConverted(entry) {
                        Text("Converted to a launchd job. The original entry is still in your crontab.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if entry.schedule == nil {
                        Text("The schedule \"\(entry.scheduleExpression)\" cannot be converted automatically.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Convert to launchd Job") {
                            confirmingConvert = true
                        }
                        Text("Creates a job with the same command and schedule that also runs after your Mac wakes from sleep.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .confirmationDialog("Convert this cron entry?", isPresented: $confirmingConvert) {
                    Button("Convert") {
                        Task { await state.convert(entry) }
                    }
                } message: {
                    Text(AppSettings.removeCronAfterConvert
                        ? "A launchd job will be created and this line will be removed from your crontab."
                        : "A launchd job will be created. The cron entry stays in your crontab and is marked Converted.")
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Schedule")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.schedule?.displayText ?? entry.scheduleExpression)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Crontab line \(entry.id)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(entry.raw)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: 640, alignment: .leading)
            .padding(28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
