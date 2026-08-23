import Foundation

/// One launchd StartCalendarInterval dictionary. A nil field matches any value,
/// mirroring launchd's own semantics.
struct CalendarRule: Codable, Hashable, Sendable {
    var minute: Int?
    var hour: Int?
    var day: Int?
    var weekday: Int?
    var month: Int?

    enum CodingKeys: String, CodingKey {
        case minute = "Minute"
        case hour = "Hour"
        case day = "Day"
        case weekday = "Weekday"
        case month = "Month"
    }
}

/// The app-level schedule model both editor modes read and write.
enum Schedule: Hashable, Sendable {
    /// launchd StartInterval: run every N seconds.
    case interval(seconds: Int)
    /// launchd StartCalendarInterval: one or more calendar rules.
    case calendar([CalendarRule])
}
