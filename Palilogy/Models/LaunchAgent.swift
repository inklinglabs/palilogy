import Foundation

/// Codable image of a launchd agent plist, limited to the keys v1 manages.
/// Decoding tolerates unknown keys but does not preserve them, which is safe
/// because only app-managed plists (containing exactly these keys) are ever
/// rewritten; foreign agents are never re-encoded.
struct LaunchAgent: Codable, Hashable, Sendable {
    var label: String
    var program: String?
    var programArguments: [String]?
    var disabled: Bool?
    var runAtLoad: Bool?
    var startInterval: Int?
    var startCalendarInterval: [CalendarRule]?
    var standardOutPath: String?
    var standardErrorPath: String?
    var workingDirectory: String?
    var environmentVariables: [String: String]?
    var palilogyManaged: Bool?
    var palilogyName: String?

    enum CodingKeys: String, CodingKey {
        case label = "Label"
        case program = "Program"
        case programArguments = "ProgramArguments"
        case disabled = "Disabled"
        case runAtLoad = "RunAtLoad"
        case startInterval = "StartInterval"
        case startCalendarInterval = "StartCalendarInterval"
        case standardOutPath = "StandardOutPath"
        case standardErrorPath = "StandardErrorPath"
        case workingDirectory = "WorkingDirectory"
        case environmentVariables = "EnvironmentVariables"
        case palilogyManaged = "PalilogyManaged"
        case palilogyName = "PalilogyName"
    }

    init(label: String) {
        self.label = label
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        label = try container.decode(String.self, forKey: .label)
        program = try container.decodeIfPresent(String.self, forKey: .program)
        programArguments = try container.decodeIfPresent([String].self, forKey: .programArguments)
        disabled = try container.decodeIfPresent(Bool.self, forKey: .disabled)
        runAtLoad = try container.decodeIfPresent(Bool.self, forKey: .runAtLoad)
        startInterval = try container.decodeIfPresent(Int.self, forKey: .startInterval)
        // launchd accepts StartCalendarInterval as a single dict or an array of dicts.
        if let rules = try? container.decodeIfPresent([CalendarRule].self, forKey: .startCalendarInterval) {
            startCalendarInterval = rules
        } else if let rule = try container.decodeIfPresent(CalendarRule.self, forKey: .startCalendarInterval) {
            startCalendarInterval = [rule]
        }
        standardOutPath = try container.decodeIfPresent(String.self, forKey: .standardOutPath)
        standardErrorPath = try container.decodeIfPresent(String.self, forKey: .standardErrorPath)
        workingDirectory = try container.decodeIfPresent(String.self, forKey: .workingDirectory)
        environmentVariables = try container.decodeIfPresent([String: String].self, forKey: .environmentVariables)
        palilogyManaged = try container.decodeIfPresent(Bool.self, forKey: .palilogyManaged)
        palilogyName = try container.decodeIfPresent(String.self, forKey: .palilogyName)
    }

    var isManaged: Bool { palilogyManaged == true }

    var schedule: Schedule? {
        if let startInterval { return .interval(seconds: startInterval) }
        if let startCalendarInterval, !startCalendarInterval.isEmpty {
            return .calendar(startCalendarInterval)
        }
        return nil
    }

    /// The command as the user thinks of it: ProgramArguments wins over Program.
    var command: [String] {
        if let programArguments, !programArguments.isEmpty { return programArguments }
        if let program { return [program] }
        return []
    }

    /// What to show as the job's name: the friendly name for managed jobs,
    /// the label otherwise.
    var displayName: String {
        palilogyName ?? label
    }

    /// The command as one line. App-created jobs run through a shell, so
    /// show just the shell command, not the zsh -c wrapper.
    var displayCommand: String {
        if command.count == 3, command[1] == "-c",
           command[0].hasSuffix("sh") {
            return command[2]
        }
        return command.joined(separator: " ")
    }
}

enum LaunchAgentCodec {
    static func decode(_ data: Data) throws -> LaunchAgent {
        try PropertyListDecoder().decode(LaunchAgent.self, from: data)
    }

    static func encode(_ agent: LaunchAgent) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        return try encoder.encode(agent)
    }
}
