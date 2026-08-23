import Foundation
import Testing
@testable import Palilogy

struct JobDraftTests {
    private func validDraft() -> JobDraft {
        var draft = JobDraft()
        draft.name = "Nightly Backup"
        draft.command = "/Users/x/bin/backup.sh"
        return draft
    }

    @Test func slugging() {
        #expect(JobDraft.slug("Nightly Backup!") == "nightly-backup")
        #expect(JobDraft.slug("  A   B  ") == "a-b")
        #expect(JobDraft.slug("???") == "job")
    }

    @Test func buildsCalendarAgentWithManagedMarkerAndLogs() throws {
        var draft = validDraft()
        draft.mode = .calendar
        draft.weekdays = [1, 5]
        draft.hour = 5
        draft.minute = 30

        let agent = try draft.buildAgent(existingLabels: [])
        #expect(agent.label == "com.inklinglabs.palilogy.nightly-backup")
        #expect(agent.palilogyManaged == true)
        #expect(agent.palilogyName == "Nightly Backup")
        #expect(agent.programArguments == ["/bin/zsh", "-c", "/Users/x/bin/backup.sh"])
        #expect(agent.startCalendarInterval == [
            CalendarRule(minute: 30, hour: 5, weekday: 1),
            CalendarRule(minute: 30, hour: 5, weekday: 5),
        ])
        #expect(agent.standardOutPath?.hasSuffix("Library/Logs/Palilogy/\(agent.label).out.log") == true)
        #expect(agent.standardErrorPath?.hasSuffix("Library/Logs/Palilogy/\(agent.label).err.log") == true)
        #expect(agent.runAtLoad == nil)
    }

    @Test func emptyWeekdaysMeansEveryDay() throws {
        var draft = validDraft()
        draft.mode = .calendar
        draft.hour = 7
        draft.minute = 0
        let agent = try draft.buildAgent(existingLabels: [])
        #expect(agent.startCalendarInterval == [CalendarRule(minute: 0, hour: 7)])
    }

    @Test func cronDraftBecomesStartInterval() throws {
        var draft = validDraft()
        draft.mode = .cron
        draft.cronText = "*/15 * * * *"
        let agent = try draft.buildAgent(existingLabels: [])
        #expect(agent.startInterval == 900)
        #expect(agent.startCalendarInterval == nil)
    }

    @Test func cronAdoptFillsIntervalPicker() {
        var draft = validDraft()
        draft.adopt(.interval(seconds: 900))
        #expect(draft.mode == .interval)
        #expect(draft.intervalValue == 15)
        #expect(draft.intervalUnit == .minutes)

        draft.adopt(.interval(seconds: 7200))
        #expect(draft.intervalValue == 2)
        #expect(draft.intervalUnit == .hours)
    }

    @Test func adoptFillsCalendarPickerForWeekdayRules() {
        var draft = validDraft()
        let adopted = draft.adopt(.calendar([
            CalendarRule(minute: 0, hour: 5, weekday: 1),
            CalendarRule(minute: 0, hour: 5, weekday: 2),
        ]))
        #expect(adopted)
        #expect(draft.mode == .calendar)
        #expect(draft.weekdays == [1, 2])
        #expect(draft.hour == 5)
        #expect(draft.minute == 0)
    }

    @Test func complexScheduleIsNotAdopted() {
        var draft = validDraft()
        let complex: Schedule = .calendar([
            CalendarRule(minute: 0, hour: 5, day: 1),
            CalendarRule(minute: 0, hour: 5, weekday: 1),
        ])
        let adopted = draft.adopt(complex)
        #expect(!adopted)
        #expect(draft.mode == .calendar)
    }

    @Test func editingComplexAgentPreservesScheduleExactly() throws {
        var agent = LaunchAgent(label: "com.inklinglabs.palilogy.odd")
        agent.palilogyManaged = true
        agent.palilogyName = "Odd"
        agent.programArguments = ["/bin/zsh", "-c", "echo hi"]
        agent.startCalendarInterval = [
            CalendarRule(minute: 0, hour: 6, day: 1),
            CalendarRule(minute: 0, hour: 6, weekday: 1),
        ]

        let draft = JobDraft(editing: agent)
        #expect(draft.mode == .advanced)
        #expect(draft.name == "Odd")
        #expect(draft.command == "echo hi")
        #expect(draft.existingLabel == agent.label)

        let rebuilt = try draft.buildAgent(existingLabels: [])
        #expect(rebuilt.label == agent.label)
        #expect(rebuilt.startCalendarInterval == agent.startCalendarInterval)
    }

    @Test func editingSimpleAgentFillsPicker() {
        var agent = LaunchAgent(label: "com.inklinglabs.palilogy.tick")
        agent.palilogyManaged = true
        agent.programArguments = ["/bin/zsh", "-c", "tick"]
        agent.startInterval = 3600
        let draft = JobDraft(editing: agent)
        #expect(draft.mode == .interval)
        #expect(draft.intervalValue == 1)
        #expect(draft.intervalUnit == .hours)
    }

    @Test func validationCatchesProblems() {
        var draft = JobDraft()
        #expect(draft.validationError(existingLabels: []) == "Give the job a name.")
        draft.name = "X"
        #expect(draft.validationError(existingLabels: []) == "Enter a command to run.")
        draft.command = "echo hi"
        #expect(draft.validationError(existingLabels: []) == nil)

        draft.mode = .cron
        draft.cronText = "61 * * * *"
        let error = draft.validationError(existingLabels: [])
        #expect(error?.contains("minute") == true)

        draft.mode = .calendar
        #expect(
            draft.validationError(existingLabels: ["com.inklinglabs.palilogy.x"])
                == "A job with this name already exists."
        )
    }

    @Test func duplicateLabelAllowedWhenEditingSelf() {
        var draft = JobDraft()
        draft.name = "X"
        draft.command = "echo hi"
        draft.existingLabel = "com.inklinglabs.palilogy.x"
        #expect(draft.validationError(existingLabels: []) == nil)
    }
}
