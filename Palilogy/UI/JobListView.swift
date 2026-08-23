import SwiftUI

struct JobListView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var state = state
        if state.scope == .cron {
            cronList(selection: $state.selectedJobID)
        } else {
            agentList(selection: $state.selectedJobID)
        }
    }

    @ViewBuilder
    private func agentList(selection: Binding<String?>) -> some View {
        if state.visibleAgents.isEmpty {
            ContentUnavailableView(
                emptyTitle,
                systemImage: "clock.badge.questionmark",
                description: Text("Jobs you schedule will appear here.")
            )
        } else {
            List(selection: selection) {
                ForEach(state.visibleAgents) { file in
                    AgentRow(file: file, isEnabled: state.isEnabled(file))
                        .tag(file.id)
                }
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private func cronList(selection: Binding<String?>) -> some View {
        if state.cronEntries.isEmpty {
            ContentUnavailableView(
                "No Cron Entries",
                systemImage: "terminal",
                description: Text("Your crontab is empty. Jobs made in this app use launchd instead.")
            )
        } else {
            List(selection: selection) {
                ForEach(state.cronEntries) { entry in
                    CronRow(entry: entry)
                        .tag("cron-\(entry.id)")
                }
            }
            .listStyle(.inset)
        }
    }

    private var emptyTitle: String {
        switch state.scope {
        case .enabled: "No Enabled Jobs"
        case .disabled: "No Disabled Jobs"
        default: "No Jobs Yet"
        }
    }
}

struct AgentRow: View {
    var file: AgentFile
    var isEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Circle()
                    .fill(isEnabled ? Color.green : Color.secondary.opacity(0.4))
                    .frame(width: 7, height: 7)
                Text(file.agent.label)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
            }
            Text(file.agent.command.joined(separator: " "))
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(file.agent.schedule?.displayText ?? "No schedule")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct CronRow: View {
    var entry: CronEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(entry.command)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            Text(entry.schedule?.displayText ?? entry.scheduleExpression)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Cron, read only")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
