import Foundation

struct CommandResult: Sendable {
    var exitCode: Int32
    var stdout: String
    var stderr: String
}

/// Abstraction over subprocess execution so services can be tested
/// without touching launchd or the crontab.
protocol CommandRunning: Sendable {
    func run(_ executable: String, _ arguments: [String], stdin: String?) async throws -> CommandResult
}

extension CommandRunning {
    func run(_ executable: String, _ arguments: [String]) async throws -> CommandResult {
        try await run(executable, arguments, stdin: nil)
    }
}

struct ProcessRunner: CommandRunning {
    func run(_ executable: String, _ arguments: [String], stdin: String?) async throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let stdin {
            // Small inputs only: a pipe buffers 64KB, plenty for a crontab.
            let stdinPipe = Pipe()
            process.standardInput = stdinPipe
            try stdinPipe.fileHandleForWriting.write(contentsOf: Data(stdin.utf8))
            try stdinPipe.fileHandleForWriting.close()
        }
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        // launchctl and crontab output stays far below the 64KB pipe buffer,
        // so reading after termination cannot deadlock.
        nonisolated(unsafe) let stdoutHandle = stdoutPipe.fileHandleForReading
        nonisolated(unsafe) let stderrHandle = stderrPipe.fileHandleForReading
        nonisolated(unsafe) let proc = process
        return try await withCheckedThrowingContinuation { continuation in
            proc.terminationHandler = { finished in
                let out = String(decoding: stdoutHandle.readDataToEndOfFile(), as: UTF8.self)
                let err = String(decoding: stderrHandle.readDataToEndOfFile(), as: UTF8.self)
                continuation.resume(returning: CommandResult(
                    exitCode: finished.terminationStatus, stdout: out, stderr: err
                ))
            }
            do {
                try proc.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
