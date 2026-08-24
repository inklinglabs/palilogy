import Testing
@testable import Palilogy

struct CronParserTests {
    @Test func everyFifteenMinutesBecomesInterval() throws {
        #expect(try CronParser.parse("*/15 * * * *") == .interval(seconds: 900))
    }

    @Test func everyMinuteBecomesInterval() throws {
        #expect(try CronParser.parse("* * * * *") == .interval(seconds: 60))
    }

    @Test func nonDivisorStepFallsBackToCalendar() throws {
        let schedule = try CronParser.parse("*/13 * * * *")
        guard case .calendar(let rules) = schedule else {
            Issue.record("expected calendar"); return
        }
        #expect(rules.map(\.minute) == [0, 13, 26, 39, 52])
        #expect(rules.allSatisfy { $0.hour == nil && $0.day == nil })
    }

    @Test func weekdaysAtFive() throws {
        let schedule = try CronParser.parse("0 5 * * 1-5")
        guard case .calendar(let rules) = schedule else {
            Issue.record("expected calendar"); return
        }
        #expect(rules.count == 5)
        #expect(rules.map(\.weekday) == [1, 2, 3, 4, 5])
        #expect(rules.allSatisfy { $0.minute == 0 && $0.hour == 5 && $0.day == nil && $0.month == nil })
    }

    @Test func listsAndNames() throws {
        let schedule = try CronParser.parse("30 9 * jan,jul mon")
        guard case .calendar(let rules) = schedule else {
            Issue.record("expected calendar"); return
        }
        #expect(rules.count == 2)
        #expect(rules.map(\.month) == [1, 7])
        #expect(rules.allSatisfy { $0.weekday == 1 && $0.minute == 30 && $0.hour == 9 })
    }

    @Test func weekdaySevenNormalizesToSunday() throws {
        let schedule = try CronParser.parse("0 0 * * 7")
        guard case .calendar(let rules) = schedule else {
            Issue.record("expected calendar"); return
        }
        #expect(rules.map(\.weekday) == [0])
    }

    @Test func dayAndWeekdayBothRestrictedEmitsUnion() throws {
        // Vixie cron: runs on the 1st of the month OR on Mondays.
        let schedule = try CronParser.parse("0 6 1 * 1")
        guard case .calendar(let rules) = schedule else {
            Issue.record("expected calendar"); return
        }
        #expect(rules.count == 2)
        #expect(rules.contains(CalendarRule(minute: 0, hour: 6, day: 1)))
        #expect(rules.contains(CalendarRule(minute: 0, hour: 6, weekday: 1)))
    }

    @Test func rangeWithStep() throws {
        let schedule = try CronParser.parse("0 8-18/4 * * *")
        guard case .calendar(let rules) = schedule else {
            Issue.record("expected calendar"); return
        }
        #expect(rules.map(\.hour) == [8, 12, 16])
    }

    @Test func minuteOutOfRangeNamesTheField() {
        #expect(throws: CronParseError.outOfRange(field: .minute, value: 61, allowed: 0...59)) {
            _ = try CronParser.parse("61 * * * *")
        }
    }

    @Test func wrongFieldCountReported() {
        #expect(throws: CronParseError.wrongFieldCount(found: 4)) {
            _ = try CronParser.parse("0 5 * *")
        }
    }

    @Test func garbageTokenReported() {
        #expect(throws: CronParseError.invalidToken(field: .weekday, token: "monday")) {
            _ = try CronParser.parse("0 5 * * monday")
        }
    }

    @Test func explosionCapEnforced() {
        #expect(throws: CronParseError.self) {
            _ = try CronParser.parse("0-59 0-23 * * *")
        }
    }

    @Test func invertedRangeRejected() {
        #expect(throws: CronParseError.invalidToken(field: .hour, token: "18-8")) {
            _ = try CronParser.parse("0 18-8 * * *")
        }
    }
}
