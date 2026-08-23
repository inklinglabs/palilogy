import Foundation
import Observation

@MainActor @Observable
final class AppState {
    enum Scope: String, CaseIterable, Identifiable, Hashable {
        case all, enabled, disabled, cron
        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: "All"
            case .enabled: "Enabled"
            case .disabled: "Disabled"
            case .cron: "Cron"
            }
        }

        var systemImage: String {
            switch self {
            case .all: "clock"
            case .enabled: "play.circle"
            case .disabled: "pause.circle"
            case .cron: "terminal"
            }
        }
    }

    var scope: Scope = .all {
        didSet { if scope != oldValue { selectedJobID = nil } }
    }
    var selectedJobID: String?
    var agents: [AgentFile] = []
    var statuses: [String: JobStatus] = [:]
    var cronEntries: [CronEntry] = []
    var isLoading = false
    var lastError: String?

    private let launchd: LaunchdService
    private let crontab: CrontabService

    init(launchd: LaunchdService = LaunchdService(), crontab: CrontabService = CrontabService()) {
        self.launchd = launchd
        self.crontab = crontab
    }

    // MARK: - Loading

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let agents = try await launchd.listAgents()
            var statuses: [String: JobStatus] = [:]
            for file in agents {
                statuses[file.agent.label] = try await launchd.status(label: file.agent.label)
            }
            self.agents = agents
            self.statuses = statuses
            self.cronEntries = try await crontab.entries()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Filtering

    var visibleAgents: [AgentFile] {
        Self.filter(agents: agents, statuses: statuses, scope: scope)
    }

    nonisolated static func filter(
        agents: [AgentFile], statuses: [String: JobStatus], scope: Scope
    ) -> [AgentFile] {
        switch scope {
        case .all: agents
        case .enabled: agents.filter { statuses[$0.agent.label]?.isLoaded == true }
        case .disabled: agents.filter { statuses[$0.agent.label]?.isLoaded != true }
        case .cron: []
        }
    }

    func isEnabled(_ file: AgentFile) -> Bool {
        statuses[file.agent.label]?.isLoaded == true
    }

    var selectedAgent: AgentFile? {
        agents.first { $0.id == selectedJobID }
    }

    var selectedCronEntry: CronEntry? {
        cronEntries.first { "cron-\($0.id)" == selectedJobID }
    }

    // MARK: - Actions

    func toggle(_ file: AgentFile) async {
        await reportingErrors {
            if self.isEnabled(file) {
                try await self.launchd.bootout(label: file.agent.label)
            } else {
                try await self.launchd.bootstrap(file.url)
            }
            self.statuses[file.agent.label] = try await self.launchd.status(label: file.agent.label)
        }
    }

    func runNow(_ file: AgentFile) async {
        await reportingErrors {
            try await self.launchd.kickstart(label: file.agent.label)
            self.statuses[file.agent.label] = try await self.launchd.status(label: file.agent.label)
        }
    }

    func delete(_ file: AgentFile) async {
        await reportingErrors {
            try await self.launchd.remove(file)
            if self.selectedJobID == file.id { self.selectedJobID = nil }
            await self.refresh()
        }
    }

    private func reportingErrors(_ work: @MainActor () async throws -> Void) async {
        do {
            try await work()
        } catch {
            lastError = error.localizedDescription
        }
    }
}
