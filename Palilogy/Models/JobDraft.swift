import Foundation

/// Everything the job editor sheet edits, with the pure logic to validate
/// a draft and build the LaunchAgent it describes. UI-free and testable.
struct JobDraft: Equatable {
    enum Mode: Equatable {
        case interval
        case calendar
        case cron
        /// The existing schedule is more complex than the picker supports;
        /// keep it exactly as it is unless the user switches modes.
        case advanced
    }

    enum IntervalUnit: String, CaseIterable, Equatable {
        case minutes, hours

        var seconds: Int {
            switch self {
            case .minutes: 60
            case .hours: 3600
            }
        }
    }

    var name = ""
    var command = ""
    var runAtLoad = false
    var mode: Mode = .calendar
    var intervalValue = 1
    var intervalUnit: IntervalUnit = .hours
    /// Empty means every day.
    var weekdays: Set<Int> = []
    var hour = 9
    var minute = 0
    var cronText = ""
    /// Set when editing; new jobs derive their label from the name.
    var existingLabel: String?
    var preservedSchedule: Schedule?

    static let labelPrefix = "com.inklinglabs.palilogy."

    init() {}

    init(editing agent: LaunchAgent) {
        name = agent.displayName
        command = agent.displayCommand
        runAtLoad = agent.runAtLoad == true
        existingLabel = agent.label
        if let schedule = agent.schedule {
            if !adopt(schedule) {
                mode = .advanced
                preservedSchedule = schedule
            }
        } else {
            mode = .advanced
        }
    }

    // MARK: - Schedule

    /// The schedule this draft describes. Throws CronParseError in cron mode.
    func schedule() throws -> Schedule? {
        switch mode {
        case .interval:
            return .interval(seconds: intervalValue * intervalUnit.seconds)
        case .calendar:
            let rule = { (weekday: Int?) in
                CalendarRule(minute: minute, hour: hour, weekday: weekday)
            }
            return .calendar(weekdays.isEmpty ? [rule(nil)] : weekdays.sorted().map(rule))
        case .cron:
            return try CronParser.parse(cronText)
        case .advanced:
            return preservedSchedule
        }
    }

    /// Sets the picker fields from a schedule when it is representable
    /// there. Returns false (leaving the draft untouched) when it is not.
    @discardableResult
    mutating func adopt(_ schedule: Schedule) -> Bool {
        switch schedule {
        case .interval(let seconds):
            let unit: IntervalUnit = seconds % 3600 == 0 ? .hours : .minutes
            guard seconds % unit.seconds == 0, seconds > 0 else { return false }
            mode = .interval
            intervalValue = seconds / unit.seconds
            intervalUnit = unit
            return true
        case .calendar(let rules):
            guard let first = rules.first, let hour = first.hour, let minute = first.minute,
                  rules.allSatisfy({
                      $0.hour == hour && $0.minute == minute && $0.day == nil && $0.month == nil
                  })
            else { return false }
            let ruleWeekdays = rules.compactMap(\.weekday)
            // Either one every-day rule, or every rule names a weekday.
            guard ruleWeekdays.isEmpty ? rules.count == 1 : ruleWeekdays.count == rules.count
            else { return false }
            mode = .calendar
            self.hour = hour
            self.minute = minute
            weekdays = Set(ruleWeekdays)
            return true
        }
    }

    // MARK: - Validation

    var label: String {
        existingLabel ?? Self.labelPrefix + Self.slug(name)
    }

    /// Nil when the draft can be saved. `existingLabels` is every label in
    /// use except this draft's own.
    func validationError(existingLabels: Set<String>) -> String? {
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Give the job a name."
        }
        if command.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Enter a command to run."
        }
        switch mode {
        case .interval where intervalValue < 1:
            return "The interval must be at least 1."
        case .cron:
            do { _ = try CronParser.parse(cronText) } catch {
                return error.localizedDescription
            }
        default:
            break
        }
        if existingLabel == nil, existingLabels.contains(label) {
            return "A job with this name already exists."
        }
        return nil
    }

    // MARK: - Building

    struct DraftError: Error, LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    func buildAgent(existingLabels: Set<String>) throws -> LaunchAgent {
        if let problem = validationError(existingLabels: existingLabels) {
            throw DraftError(message: problem)
        }
        var agent = LaunchAgent(label: label)
        agent.palilogyManaged = true
        agent.palilogyName = name.trimmingCharacters(in: .whitespaces)
        agent.programArguments = ["/bin/zsh", "-c", command.trimmingCharacters(in: .whitespaces)]
        if runAtLoad { agent.runAtLoad = true }
        switch try schedule() {
        case .interval(let seconds): agent.startInterval = seconds
        case .calendar(let rules): agent.startCalendarInterval = rules
        case nil: break
        }
        let logs = Self.logDirectory.path
        agent.standardOutPath = "\(logs)/\(label).out.log"
        agent.standardErrorPath = "\(logs)/\(label).err.log"
        return agent
    }

    static let logDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Logs/Palilogy")

    /// "Nightly Backup!" -> "nightly-backup"
    static func slug(_ name: String) -> String {
        let slug = name.lowercased()
            .map { $0.isLetter || $0.isNumber ? $0 : "-" }
            .reduce(into: "") { result, char in
                if char != "-" || result.last != "-" { result.append(char) }
            }
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "job" : slug
    }
}
