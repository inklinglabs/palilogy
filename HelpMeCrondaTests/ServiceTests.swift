import Foundation
import Testing
@testable import HelpMeCronda

/// Records invocations and replays canned results, keyed by executable + first arg.
final class MockRunner: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(executable: String, arguments: [String])] = []
    var results: [String: CommandResult] = [:]

    var calls: [(executable: String, arguments: [String])] {
        lock.withLock { _calls }
    }

    func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        lock.withLock { _calls.append((executable, arguments)) }
        let key = ([executable] + arguments.prefix(1)).joined(separator: " ")
        return results[key] ?? CommandResult(exitCode: 0, stdout: "", stderr: "")
    }
}

struct LaunchdServiceTests {
    @Test func parsePrintOutputExtractsPidAndExitCode() {
        let output = """
        gui/501/com.example.job = {
        	active count = 1
        	path = /Users/x/Library/LaunchAgents/com.example.job.plist
        	state = running
        	pid = 4242
        	last exit code = 78
        }
        """
        let status = LaunchdService.parsePrintOutput(output)
        #expect(status == JobStatus(isLoaded: true, pid: 4242, lastExitCode: 78))
    }

    @Test func parsePrintOutputNeverExited() {
        let output = """
        gui/501/com.example.job = {
        	state = waiting
        	last exit code = (never exited)
        }
        """
        let status = LaunchdService.parsePrintOutput(output)
        #expect(status.isLoaded)
        #expect(status.lastExitCode == nil)
        #expect(status.pid == nil)
    }

    @Test func statusForUnloadedJobIsNotLoaded() async throws {
        let runner = MockRunner()
        runner.results["/bin/launchctl print"] = CommandResult(
            exitCode: 113, stdout: "", stderr: "Could not find service"
        )
        let service = LaunchdService(runner: runner, uid: 501)
        let status = try await service.status(label: "com.example.gone")
        #expect(status == .notLoaded)
    }

    @Test func bootstrapAndBootoutUseGuiDomain() async throws {
        let runner = MockRunner()
        let service = LaunchdService(runner: runner, uid: 501)
        try await service.bootstrap(URL(fileURLWithPath: "/tmp/a.plist"))
        try await service.bootout(label: "com.example.job")
        #expect(runner.calls[0].arguments == ["bootstrap", "gui/501", "/tmp/a.plist"])
        #expect(runner.calls[1].arguments == ["bootout", "gui/501/com.example.job"])
    }

    @Test func failedLaunchctlThrowsWithStderr() async {
        let runner = MockRunner()
        runner.results["/bin/launchctl bootstrap"] = CommandResult(
            exitCode: 5, stdout: "", stderr: "Input/output error"
        )
        let service = LaunchdService(runner: runner, uid: 501)
        await #expect(throws: LaunchdError.self) {
            try await service.bootstrap(URL(fileURLWithPath: "/tmp/a.plist"))
        }
    }

    @Test func writeThenListRoundTrips() async throws {
        let dir = FileManager.default.temporaryDirectory
            .appending(path: "hmc-test-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let service = LaunchdService(runner: MockRunner(), agentsDirectory: dir, uid: 501)

        var agent = LaunchAgent(label: "com.inklinglabs.helpmecronda.t")
        agent.programArguments = ["/usr/bin/true"]
        agent.startInterval = 60
        agent.helpMeCrondaManaged = true

        let url = try await service.write(agent)
        #expect(url.lastPathComponent == "com.inklinglabs.helpmecronda.t.plist")
        let listed = try await service.listAgents()
        #expect(listed.map(\.agent) == [agent])
    }
}

struct CrontabServiceTests {
    @Test func emptyCrontabIsEmptyListNotError() async throws {
        let runner = MockRunner()
        runner.results["/usr/bin/crontab -l"] = CommandResult(
            exitCode: 1, stdout: "", stderr: "crontab: no crontab for matt"
        )
        let service = CrontabService(runner: runner)
        #expect(try await service.entries().isEmpty)
    }

    @Test func parsesEntriesSkippingCommentsAndEnvironment() {
        let text = """
        # backups
        SHELL=/bin/zsh
        MAILTO=matt@example.com

        0 5 * * 1-5 /Users/matt/bin/backup.sh --fast
        @daily /usr/local/bin/cleanup
        not a valid line
        """
        let entries = CrontabService.parse(text)
        #expect(entries.count == 2)
        #expect(entries[0].scheduleExpression == "0 5 * * 1-5")
        #expect(entries[0].command == "/Users/matt/bin/backup.sh --fast")
        #expect(entries[0].id == 5)
        #expect(entries[1].scheduleExpression == "@daily")
        #expect(entries[1].command == "/usr/local/bin/cleanup")
    }

    @Test func fiveFieldEntryExposesParsedSchedule() {
        let entries = CrontabService.parse("*/15 * * * * /usr/bin/true")
        #expect(entries.first?.schedule == .interval(seconds: 900))
    }

    @Test func atKeywordEntryHasNoScheduleSoCannotConvert() {
        let entries = CrontabService.parse("@reboot /usr/bin/true")
        #expect(entries.first != nil)
        #expect(entries.first?.schedule == nil)
    }
}

struct ProcessRunnerTests {
    @Test func runsARealProcessAndCapturesStreams() async throws {
        let result = try await ProcessRunner().run("/bin/sh", ["-c", "echo out; echo err 1>&2; exit 3"])
        #expect(result.exitCode == 3)
        #expect(result.stdout == "out\n")
        #expect(result.stderr == "err\n")
    }
}
