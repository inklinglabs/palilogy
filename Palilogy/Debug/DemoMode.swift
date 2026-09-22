import Foundation

/// Demo mode: run the app against invented jobs, so screenshots never show
/// anyone's real LaunchAgents, crontab, or user name. Debug builds only; in
/// Release `isActive` is always false and the fixtures are not compiled.
///
///     PALILOGY_DEMO=1 path/to/Palilogy.app/Contents/MacOS/Palilogy
///
/// The snapshot harness (`PALILOGY_SNAPSHOT_DIR`) always runs in demo mode.
/// Fixtures are rewritten into the app's Caches folder on every launch.
/// launchctl and crontab are never called: a canned runner answers instead,
/// so no real job is read, loaded, or changed.
enum DemoMode {
    static var isActive: Bool {
        #if DEBUG
        let env = ProcessInfo.processInfo.environment
        return env["PALILOGY_DEMO"] == "1" || !(env["PALILOGY_SNAPSHOT_DIR"] ?? "").isEmpty
        #else
        return false
        #endif
    }

    /// Shows fixture paths as if they lived in the user's Library.
    static func displayPath(_ path: String) -> String {
        #if DEBUG
        if isActive, path.hasPrefix(root.path) {
            return "~/Library" + path.dropFirst(root.path.count)
        }
        #endif
        return path
    }

    @MainActor
    static func makeAppState() -> AppState {
        #if DEBUG
        if isActive {
            let runner = prepareFixtures()
            return AppState(
                launchd: LaunchdService(
                    runner: runner, agentsDirectory: root.appending(path: "LaunchAgents"), uid: 501
                ),
                crontab: CrontabService(runner: runner)
            )
        }
        #endif
        return AppState()
    }
}

#if DEBUG
extension DemoMode {
    /// Stands in for ~/Library: holds LaunchAgents/ and Logs/Palilogy/.
    static let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appending(path: "com.inklinglabs.palilogy/Demo")

    struct Status: Sendable {
        var loaded = true
        var pid: Int?
        var lastExit: Int?
    }

    /// Answers the launchctl and crontab calls the services make.
    struct Runner: CommandRunning {
        let statuses: [String: Status]
        let crontab: String

        func run(_ executable: String, _ arguments: [String], stdin: String?) async throws -> CommandResult {
            let ok = CommandResult(exitCode: 0, stdout: "", stderr: "")
            if executable.hasSuffix("crontab") {
                return arguments == ["-l"] ? CommandResult(exitCode: 0, stdout: crontab, stderr: "") : ok
            }
            guard arguments.first == "print", let target = arguments.last else { return ok }
            let label = String(target.split(separator: "/").last ?? "")
            guard let status = statuses[label], status.loaded else {
                return CommandResult(exitCode: 113, stdout: "", stderr: "Could not find service")
            }
            var out = "\(target) = {\n\tstate = \(status.pid == nil ? "waiting" : "running")\n"
            if let pid = status.pid { out += "\tpid = \(pid)\n" }
            out += "\tlast exit code = \(status.lastExit.map(String.init) ?? "(never exited)")\n}\n"
            return CommandResult(exitCode: 0, stdout: out, stderr: "")
        }
    }

    private struct Fixture {
        var agent: LaunchAgent
        var status: Status
        var stdout = ""
        var stderr = ""
    }

    private static func managed(
        _ name: String, _ command: String, interval: Int? = nil, rules: [CalendarRule]? = nil
    ) -> LaunchAgent {
        var agent = LaunchAgent(label: JobDraft.labelPrefix + JobDraft.slug(name))
        agent.palilogyManaged = true
        agent.palilogyName = name
        agent.programArguments = ["/bin/zsh", "-c", command]
        agent.startInterval = interval
        agent.startCalendarInterval = rules
        let logs = root.appending(path: "Logs/Palilogy").path
        agent.standardOutPath = "\(logs)/\(agent.label).out.log"
        agent.standardErrorPath = "\(logs)/\(agent.label).err.log"
        return agent
    }

    private static func foreign(_ label: String, _ arguments: [String]) -> LaunchAgent {
        var agent = LaunchAgent(label: label)
        agent.programArguments = arguments
        agent.runAtLoad = true
        return agent
    }

    private static let backupRun = """
        open repository
        lock repository
        using parent snapshot 7c1e9a42
        start scan on [~/Documents ~/Projects]
        start backup on [~/Documents ~/Projects]
        scan finished in 3.412s: 48211 files, 61.874 GiB

        Files:          23 new,   211 changed, 47977 unmodified
        Dirs:            4 new,    36 changed,  7102 unmodified
        Added to the repository: 486.119 MiB (451.330 MiB stored)

        processed 48211 files, 61.874 GiB in 1:57
        snapshot 3f8b20d6 saved

        """

    private static var fixtures: [Fixture] {
        [
            Fixture(
                agent: managed("Nightly Backup", "/opt/homebrew/bin/restic backup ~/Documents ~/Projects",
                               rules: [CalendarRule(minute: 30, hour: 2)]),
                status: Status(lastExit: 0),
                stdout: backupRun + "\n" + backupRun.replacingOccurrences(of: "3f8b20d6", with: "a91c05e7")
            ),
            Fixture(
                agent: managed("Clean Downloads", "find ~/Downloads -type f -mtime +30 -delete",
                               rules: [CalendarRule(minute: 0, hour: 9, weekday: 0)]),
                status: Status(lastExit: 0)
            ),
            Fixture(
                agent: managed("Sync Photos to NAS", "rsync -a --delete ~/Pictures/Export/ nas.local:/volume1/photos/",
                               interval: 21600),
                status: Status(lastExit: 255),
                stderr: """
                    ssh: connect to host nas.local port 22: Operation timed out
                    rsync: connection unexpectedly closed (0 bytes received so far) [sender]
                    rsync error: unexplained error (code 255) at io.c(232) [sender=3.2.7]

                    """
            ),
            Fixture(
                agent: managed("Dotfiles Pull", "cd ~/.dotfiles && git pull --ff-only", interval: 3600),
                status: Status(loaded: false)
            ),
            Fixture(
                agent: managed("Daily Summary", "python3 ~/scripts/daily_summary.py --email",
                               rules: (1...5).map { CalendarRule(minute: 30, hour: 8, weekday: $0) }),
                status: Status(lastExit: 0),
                stdout: "Summary sent: 14 new emails, 3 events today, 2 reminders due.\n"
            ),
            Fixture(
                agent: foreign("homebrew.mxcl.postgresql@16", [
                    "/opt/homebrew/opt/postgresql@16/bin/postgres", "-D", "/opt/homebrew/var/postgresql@16",
                ]),
                status: Status(pid: 612)
            ),
            Fixture(
                agent: foreign("homebrew.mxcl.syncthing", [
                    "/opt/homebrew/opt/syncthing/bin/syncthing", "serve", "--no-browser", "--no-restart",
                ]),
                status: Status(pid: 733)
            ),
        ]
    }

    private static let crontab = """
        # m h dom mon dow command
        MAILTO=""

        */15 * * * * /usr/local/bin/check-disk-space.sh
        0 7 * * 1-5 ~/bin/prepare-standup-notes.sh
        @reboot /usr/local/bin/mount-network-shares.sh

        """

    /// Rewrites the fixture folder and returns the runner that answers for it.
    static func prepareFixtures() -> Runner {
        let fm = FileManager.default
        try? fm.removeItem(at: root)
        let agents = root.appending(path: "LaunchAgents")
        let logs = root.appending(path: "Logs/Palilogy")
        try? fm.createDirectory(at: agents, withIntermediateDirectories: true)
        try? fm.createDirectory(at: logs, withIntermediateDirectories: true)

        var statuses: [String: Status] = [:]
        for fixture in fixtures {
            let agent = fixture.agent
            statuses[agent.label] = fixture.status
            if let data = try? LaunchAgentCodec.encode(agent) {
                try? data.write(to: agents.appending(path: "\(agent.label).plist"))
            }
            if let path = agent.standardOutPath { try? Data(fixture.stdout.utf8).write(to: URL(fileURLWithPath: path)) }
            if let path = agent.standardErrorPath { try? Data(fixture.stderr.utf8).write(to: URL(fileURLWithPath: path)) }
        }
        return Runner(statuses: statuses, crontab: crontab)
    }
}
#endif
