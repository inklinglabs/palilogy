import Foundation

/// One scheduled line from the user's crontab, read-only in v1.
struct CronEntry: Hashable, Sendable, Identifiable {
    /// 1-based line number in the crontab; stable enough for list identity
    /// because the app never writes the crontab.
    var id: Int
    /// The schedule part: five fields, or an @keyword like @daily.
    var scheduleExpression: String
    var command: String
    var raw: String

    /// The entry's schedule, when the expression is 5-field cron the parser
    /// understands. Nil for @keywords and unparseable lines; those still
    /// display but cannot Convert.
    var schedule: Schedule? {
        try? CronParser.parse(scheduleExpression)
    }
}

/// Reads and parses the user's crontab via `crontab -l`. Never writes.
actor CrontabService {
    private let runner: any CommandRunning

    static let crontab = "/usr/bin/crontab"

    init(runner: any CommandRunning = ProcessRunner()) {
        self.runner = runner
    }

    /// The user's cron entries. An empty crontab (`crontab -l` exits
    /// non-zero with "no crontab for <user>") is an empty list, not an error.
    func entries() async throws -> [CronEntry] {
        let result = try await runner.run(Self.crontab, ["-l"])
        guard result.exitCode == 0 else {
            if result.stderr.contains("no crontab") { return [] }
            throw LaunchdError(operation: "crontab -l", exitCode: result.exitCode, stderr: result.stderr)
        }
        return Self.parse(result.stdout)
    }

    /// Removes an entry's line from the crontab. The one crontab write in
    /// the app, opt-in behind the clean-up-after-convert setting.
    func removeEntry(_ entry: CronEntry) async throws {
        let result = try await runner.run(Self.crontab, ["-l"])
        guard result.exitCode == 0 else {
            throw LaunchdError(operation: "crontab -l", exitCode: result.exitCode, stderr: result.stderr)
        }
        guard let updated = Self.removing(line: entry.raw, from: result.stdout) else {
            throw LaunchdError(
                operation: "crontab update", exitCode: 1,
                stderr: "The entry was not found; the crontab may have changed since it was read."
            )
        }
        // Installed via stdin: crontab truncates a filename argument at 100
        // characters (Vixie MAX_TEMPSTR), which temp-dir paths exceed.
        let write = try await runner.run(Self.crontab, ["-"], stdin: updated)
        guard write.exitCode == 0 else {
            throw LaunchdError(operation: "crontab write", exitCode: write.exitCode, stderr: write.stderr)
        }
    }

    /// The crontab text without the first line exactly equal to `raw`, or
    /// nil when no such line exists.
    static func removing(line raw: String, from crontabText: String) -> String? {
        var lines = crontabText.components(separatedBy: "\n")
        guard let index = lines.firstIndex(of: raw) else { return nil }
        lines.remove(at: index)
        return lines.joined(separator: "\n")
    }

    static func parse(_ crontabText: String) -> [CronEntry] {
        var entries: [CronEntry] = []
        for (index, rawLine) in crontabText.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }
            // Environment assignments (SHELL=/bin/sh, MAILTO=...) are not jobs.
            if isEnvironmentAssignment(line) { continue }

            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            if line.hasPrefix("@") {
                guard fields.count >= 2 else { continue }
                entries.append(CronEntry(
                    id: index + 1,
                    scheduleExpression: fields[0],
                    command: fields.dropFirst().joined(separator: " "),
                    raw: String(rawLine)
                ))
            } else {
                guard fields.count >= 6 else { continue }
                entries.append(CronEntry(
                    id: index + 1,
                    scheduleExpression: fields.prefix(5).joined(separator: " "),
                    command: fields.dropFirst(5).joined(separator: " "),
                    raw: String(rawLine)
                ))
            }
        }
        return entries
    }

    /// NAME=value with no whitespace before the "=", per crontab(5).
    private static func isEnvironmentAssignment(_ line: String) -> Bool {
        guard let equals = line.firstIndex(of: "=") else { return false }
        let name = line[line.startIndex..<equals]
        return !name.isEmpty && !name.contains(where: \.isWhitespace)
    }
}
