import Foundation
import Testing
@testable import HelpMeCronda

struct ScheduleFormatterTests {
    @Test func intervalDescriptions() {
        #expect(Schedule.interval(seconds: 60).displayText == "Every minute")
        #expect(Schedule.interval(seconds: 900).displayText == "Every 15 minutes")
        #expect(Schedule.interval(seconds: 3600).displayText == "Every hour")
        #expect(Schedule.interval(seconds: 7200).displayText == "Every 2 hours")
    }

    @Test func weekdaysAtSharedTime() throws {
        let schedule = try CronParser.parse("0 5 * * 1-5")
        #expect(schedule.displayText == "Weekdays at 5:00")
    }

    @Test func singleRuleDescriptions() {
        #expect(Schedule.calendar([CalendarRule(minute: 30, hour: 9, weekday: 1)]).displayText
            == "Mondays at 9:30")
        #expect(Schedule.calendar([CalendarRule(minute: 0, hour: 5)]).displayText
            == "Every day at 5:00")
        #expect(Schedule.calendar([CalendarRule(minute: 15)]).displayText
            == "Every day at minute 15 of every hour")
    }

    @Test func manyRulesFallBackToCount() throws {
        let schedule = try CronParser.parse("0 8,12,16 1,15 * *")
        #expect(schedule.displayText == "6 schedule rules")
    }
}

struct AppStateFilterTests {
    private func agentFile(_ label: String) -> AgentFile {
        var agent = LaunchAgent(label: label)
        agent.programArguments = ["/usr/bin/true"]
        return AgentFile(url: URL(fileURLWithPath: "/tmp/\(label).plist"), agent: agent)
    }

    @Test func scopesFilterByLoadedStatus() {
        let a = agentFile("com.example.a")
        let b = agentFile("com.example.b")
        let statuses = [
            "com.example.a": JobStatus(isLoaded: true),
            "com.example.b": JobStatus.notLoaded,
        ]
        #expect(AppState.filter(agents: [a, b], statuses: statuses, scope: .all) == [a, b])
        #expect(AppState.filter(agents: [a, b], statuses: statuses, scope: .enabled) == [a])
        #expect(AppState.filter(agents: [a, b], statuses: statuses, scope: .disabled) == [b])
        #expect(AppState.filter(agents: [a, b], statuses: statuses, scope: .cron).isEmpty)
    }

    @Test func unknownStatusCountsAsDisabled() {
        let a = agentFile("com.example.a")
        #expect(AppState.filter(agents: [a], statuses: [:], scope: .disabled) == [a])
        #expect(AppState.filter(agents: [a], statuses: [:], scope: .enabled).isEmpty)
    }
}
