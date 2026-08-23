import Foundation

enum CronField: String, CaseIterable, Sendable {
    case minute, hour, day, month, weekday

    var allowedRange: ClosedRange<Int> {
        switch self {
        case .minute: 0...59
        case .hour: 0...23
        case .day: 1...31
        case .month: 1...12
        case .weekday: 0...7
        }
    }

    var names: [String: Int] {
        switch self {
        case .month:
            ["jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
             "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12]
        case .weekday:
            ["sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6]
        default:
            [:]
        }
    }
}

enum CronParseError: Error, Equatable, LocalizedError {
    case wrongFieldCount(found: Int)
    case invalidToken(field: CronField, token: String)
    case outOfRange(field: CronField, value: Int, allowed: ClosedRange<Int>)
    case tooManyRules(count: Int, max: Int)

    var errorDescription: String? {
        switch self {
        case .wrongFieldCount(let found):
            "A cron expression has 5 fields (minute, hour, day, month, weekday); this one has \(found)."
        case .invalidToken(let field, let token):
            "\"\(token)\" is not a valid \(field.rawValue) value."
        case .outOfRange(let field, let value, let allowed):
            "\(value) is out of range for \(field.rawValue) (allowed: \(allowed.lowerBound) to \(allowed.upperBound))."
        case .tooManyRules(let count, let max):
            "This expression expands to \(count) schedule rules; the maximum is \(max)."
        }
    }
}

/// Parses 5-field cron expressions into the app's Schedule model.
///
/// `*/N` on the minute field with all other fields `*` becomes
/// `.interval` when N divides 60 evenly; everything else expands to
/// `.calendar` rules. When both day and weekday are restricted, cron
/// runs the job if either matches, so both sets of rules are emitted.
enum CronParser {
    static let maxRules = 128

    /// A parsed field: nil means "*" (any value).
    private typealias FieldValues = [Int]?

    static func parse(_ expression: String) throws -> Schedule {
        let fields = expression.split(whereSeparator: \.isWhitespace).map(String.init)
        guard fields.count == 5 else {
            throw CronParseError.wrongFieldCount(found: fields.count)
        }

        // Interval shortcut: "*/N * * * *" (or "* * * * *") with N dividing 60.
        if fields[1...4].allSatisfy({ $0 == "*" }) {
            if fields[0] == "*" { return .interval(seconds: 60) }
            if let step = starStep(fields[0]), step <= 60, 60 % step == 0 {
                return .interval(seconds: step * 60)
            }
        }

        let minutes = try parseField(fields[0], as: .minute)
        let hours = try parseField(fields[1], as: .hour)
        let days = try parseField(fields[2], as: .day)
        let months = try parseField(fields[3], as: .month)
        let weekdays = try parseField(fields[4], as: .weekday)

        var rules: [CalendarRule] = []
        // Vixie cron: when day and weekday are both restricted, match either.
        if days != nil && weekdays != nil {
            rules += expand(minutes: minutes, hours: hours, days: days, months: months, weekdays: nil)
            rules += expand(minutes: minutes, hours: hours, days: nil, months: months, weekdays: weekdays)
        } else {
            rules = expand(minutes: minutes, hours: hours, days: days, months: months, weekdays: weekdays)
        }

        var seen = Set<CalendarRule>()
        rules = rules.filter { seen.insert($0).inserted }
        guard rules.count <= maxRules else {
            throw CronParseError.tooManyRules(count: rules.count, max: maxRules)
        }
        return .calendar(rules)
    }

    // MARK: - Field parsing

    /// "*/N" -> N, anything else -> nil.
    private static func starStep(_ token: String) -> Int? {
        guard token.hasPrefix("*/"), let step = Int(token.dropFirst(2)), step > 0 else { return nil }
        return step
    }

    private static func parseField(_ token: String, as field: CronField) throws -> FieldValues {
        if token == "*" { return nil }
        var values: [Int] = []
        for item in token.split(separator: ",", omittingEmptySubsequences: false) {
            values += try parseItem(String(item), as: field)
        }
        guard !values.isEmpty else {
            throw CronParseError.invalidToken(field: field, token: token)
        }
        var seen = Set<Int>()
        return values.sorted().filter { seen.insert($0).inserted }
    }

    /// One comma-separated item: N, N-M, N-M/S, */S, N/S, or a name (jan, mon).
    private static func parseItem(_ item: String, as field: CronField) throws -> [Int] {
        let parts = item.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count <= 2, !parts[0].isEmpty else {
            throw CronParseError.invalidToken(field: field, token: item)
        }
        var step = 1
        if parts.count == 2 {
            guard let s = Int(parts[1]), s > 0 else {
                throw CronParseError.invalidToken(field: field, token: item)
            }
            step = s
        }

        let base = String(parts[0])
        let range: ClosedRange<Int>
        if base == "*" {
            range = field.allowedRange
        } else if let bounds = try parseRange(base, as: field) {
            range = bounds
        } else {
            let value = try parseValue(base, as: field)
            // "N/S" means N through max, per Vixie cron. Bare "N" is just N.
            range = step > 1 || parts.count == 2 ? value...field.allowedRange.upperBound : value...value
        }
        return stride(from: range.lowerBound, through: range.upperBound, by: step)
            .map { field == .weekday && $0 == 7 ? 0 : $0 }
    }

    /// "A-B" -> A...B, nil if the item has no dash.
    private static func parseRange(_ base: String, as field: CronField) throws -> ClosedRange<Int>? {
        let bounds = base.split(separator: "-", omittingEmptySubsequences: false)
        guard bounds.count == 2 else { return nil }
        let lo = try parseValue(String(bounds[0]), as: field)
        let hi = try parseValue(String(bounds[1]), as: field)
        guard lo <= hi else {
            throw CronParseError.invalidToken(field: field, token: base)
        }
        return lo...hi
    }

    private static func parseValue(_ token: String, as field: CronField) throws -> Int {
        let value: Int
        if let number = Int(token) {
            value = number
        } else if let named = field.names[token.lowercased()] {
            value = named
        } else {
            throw CronParseError.invalidToken(field: field, token: token)
        }
        guard field.allowedRange.contains(value) else {
            throw CronParseError.outOfRange(field: field, value: value, allowed: field.allowedRange)
        }
        return value
    }

    // MARK: - Expansion

    private static func expand(
        minutes: FieldValues, hours: FieldValues, days: FieldValues,
        months: FieldValues, weekdays: FieldValues
    ) -> [CalendarRule] {
        var rules: [CalendarRule] = []
        for month in months.map({ $0.map(Optional.some) }) ?? [nil] {
            for day in days.map({ $0.map(Optional.some) }) ?? [nil] {
                for weekday in weekdays.map({ $0.map(Optional.some) }) ?? [nil] {
                    for hour in hours.map({ $0.map(Optional.some) }) ?? [nil] {
                        for minute in minutes.map({ $0.map(Optional.some) }) ?? [nil] {
                            rules.append(CalendarRule(
                                minute: minute, hour: hour, day: day,
                                weekday: weekday, month: month
                            ))
                        }
                    }
                }
            }
        }
        return rules
    }
}
