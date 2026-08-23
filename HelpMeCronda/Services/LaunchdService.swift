import Foundation

struct JobStatus: Hashable, Sendable {
    var isLoaded: Bool
    var pid: Int?
    var lastExitCode: Int?

    static let notLoaded = JobStatus(isLoaded: false)
}

struct AgentFile: Hashable, Sendable, Identifiable {
    var url: URL
    var agent: LaunchAgent
    var id: String { agent.label }
}

struct LaunchdError: Error, LocalizedError {
    var operation: String
    var exitCode: Int32
    var stderr: String

    var errorDescription: String? {
        let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        return "launchctl \(operation) failed (exit \(exitCode))\(detail.isEmpty ? "" : ": \(detail)")"
    }
}

/// All launchd interaction: listing agent plists and driving launchctl.
actor LaunchdService {
    private let runner: any CommandRunning
    private let agentsDirectory: URL
    private let domain: String

    static let launchctl = "/bin/launchctl"

    init(
        runner: any CommandRunning = ProcessRunner(),
        agentsDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents"),
        uid: uid_t = getuid()
    ) {
        self.runner = runner
        self.agentsDirectory = agentsDirectory
        self.domain = "gui/\(uid)"
    }

    /// Decodable plists in ~/Library/LaunchAgents, sorted by label.
    /// Plists the codec cannot read are skipped, not fatal: the directory
    /// routinely contains third-party files with exotic keys or formats.
    func listAgents() throws -> [AgentFile] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: agentsDirectory, includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "plist" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let agent = try? LaunchAgentCodec.decode(data) else { return nil }
                return AgentFile(url: url, agent: agent)
            }
            .sorted { $0.agent.label < $1.agent.label }
    }

    /// Writes the agent's plist into ~/Library/LaunchAgents and returns its URL.
    func write(_ agent: LaunchAgent) throws -> URL {
        try FileManager.default.createDirectory(
            at: agentsDirectory, withIntermediateDirectories: true
        )
        let url = agentsDirectory.appending(path: "\(agent.label).plist")
        try LaunchAgentCodec.encode(agent).write(to: url, options: .atomic)
        return url
    }

    func bootstrap(_ plistURL: URL) async throws {
        try await launchctl("bootstrap", [domain, plistURL.path])
    }

    func bootout(label: String) async throws {
        try await launchctl("bootout", ["\(domain)/\(label)"])
    }

    func kickstart(label: String) async throws {
        try await launchctl("kickstart", ["\(domain)/\(label)"])
    }

    func status(label: String) async throws -> JobStatus {
        let result = try await runner.run(Self.launchctl, ["print", "\(domain)/\(label)"])
        guard result.exitCode == 0 else { return .notLoaded }
        return Self.parsePrintOutput(result.stdout)
    }

    private func launchctl(_ operation: String, _ arguments: [String]) async throws {
        let result = try await runner.run(Self.launchctl, [operation] + arguments)
        guard result.exitCode == 0 else {
            throw LaunchdError(
                operation: operation, exitCode: result.exitCode, stderr: result.stderr
            )
        }
    }

    /// Extracts what v1 shows from `launchctl print` output. The format is
    /// not a stable API; unknown layouts degrade to "loaded, nothing else".
    static func parsePrintOutput(_ output: String) -> JobStatus {
        var status = JobStatus(isLoaded: true)
        for line in output.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespaces)
            let value = parts[1].trimmingCharacters(in: .whitespaces)
            switch key {
            case "pid": status.pid = Int(value)
            case "last exit code":
                // launchctl prints "(never exited)" for jobs that have not run.
                status.lastExitCode = Int(value)
            default: break
            }
        }
        return status
    }
}
