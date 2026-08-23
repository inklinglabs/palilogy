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
