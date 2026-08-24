import Foundation

enum CronConversion {
    /// The LaunchAgent equivalent of a cron entry, or nil when the entry's
    /// schedule cannot be parsed (@keywords, malformed fields).
    static func agent(for entry: CronEntry, existingLabels: Set<String>) -> LaunchAgent? {
        guard let schedule = entry.schedule else { return nil }

        let name = displayName(for: entry)
        let base = JobDraft.labelPrefix + JobDraft.slug(name)
        var label = base
        var counter = 2
        while existingLabels.contains(label) {
            label = "\(base)-\(counter)"
            counter += 1
        }

        var agent = LaunchAgent(label: label)
        agent.palilogyManaged = true
        agent.palilogyName = name
        agent.programArguments = ["/bin/zsh", "-c", entry.command]
        switch schedule {
        case .interval(let seconds): agent.startInterval = seconds
        case .calendar(let rules): agent.startCalendarInterval = rules
        }
        let logs = JobDraft.logDirectory.path
        agent.standardOutPath = "\(logs)/\(label).out.log"
        agent.standardErrorPath = "\(logs)/\(label).err.log"
        return agent
    }

    /// "/Users/x/bin/backup.sh --fast" -> "backup.sh"
    static func displayName(for entry: CronEntry) -> String {
        let first = entry.command.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
        let base = (first as NSString).lastPathComponent
        return base.isEmpty ? "Converted Job" : base
    }
}
