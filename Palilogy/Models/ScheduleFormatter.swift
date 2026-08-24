import Foundation

extension Schedule {
    /// Short human-readable description for list rows and the detail pane.
    var displayText: String {
        switch self {
        case .interval(let seconds):
            Self.intervalText(seconds: seconds)
        case .calendar(let rules):
            Self.calendarText(rules: rules)
        }
    }

    private static func intervalText(seconds: Int) -> String {
        if seconds % 3600 == 0 {
            let hours = seconds / 3600
            return hours == 1 ? "Every hour" : "Every \(hours) hours"
        }
        if seconds % 60 == 0 {
            let minutes = seconds / 60
            return minutes == 1 ? "Every minute" : "Every \(minutes) minutes"
        }
        return "Every \(seconds) seconds"
    }

    private static let weekdayNames = [
        "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday",
    ]

    private static func calendarText(rules: [CalendarRule]) -> String {
        guard let first = rules.first else { return "No schedule" }

        // All rules share the same time and differ only by weekday.
        let sharedTime = rules.allSatisfy {
            $0.minute == first.minute && $0.hour == first.hour
                && $0.day == nil && $0.month == nil
        }
        if sharedTime, rules.count > 1, rules.allSatisfy({ $0.weekday != nil }) {
            let weekdays = rules.compactMap(\.weekday).sorted()
            let days = weekdays == [1, 2, 3, 4, 5]
                ? "Weekdays"
                : weekdays.map { String(weekdayNames[$0].prefix(3)) }.joined(separator: ", ")
            return "\(days) at \(timeText(first))"
        }
        if rules.count == 1 {
            return singleRuleText(first)
        }
        return "\(rules.count) schedule rules"
    }

    private static func singleRuleText(_ rule: CalendarRule) -> String {
        var parts: [String] = []
        if let weekday = rule.weekday {
            parts.append("\(weekdayNames[weekday])s")
        }
        if let day = rule.day {
            parts.append("day \(day) of the month")
        }
        if let month = rule.month {
            parts.append(Calendar.current.monthSymbols[month - 1])
        }
        let time: String
        if rule.hour != nil {
            time = "at \(timeText(rule))"
        } else if let minute = rule.minute {
            time = "at minute \(minute) of every hour"
        } else {
            time = ""
        }
        if parts.isEmpty {
            return time.isEmpty ? "Every day" : "Every day \(time)"
        }
        let base = parts.joined(separator: ", ")
        return time.isEmpty ? base : "\(base) \(time)"
    }

    private static func timeText(_ rule: CalendarRule) -> String {
        String(format: "%d:%02d", rule.hour ?? 0, rule.minute ?? 0)
    }
}
