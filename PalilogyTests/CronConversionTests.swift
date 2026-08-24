import Testing
@testable import Palilogy

struct CronConversionTests {
    private let entry = CronEntry(
        id: 1,
        scheduleExpression: "0 5 * * 1-5",
        command: "/Users/x/bin/backup.sh --fast",
        raw: "0 5 * * 1-5 /Users/x/bin/backup.sh --fast"
    )

    @Test func buildsEquivalentManagedAgent() throws {
        let agent = try #require(CronConversion.agent(for: entry, existingLabels: []))
        #expect(agent.label == "com.inklinglabs.palilogy.backup-sh")
        #expect(agent.palilogyName == "backup.sh")
        #expect(agent.palilogyManaged == true)
        #expect(agent.programArguments == ["/bin/zsh", "-c", "/Users/x/bin/backup.sh --fast"])
        #expect(agent.startCalendarInterval?.count == 5)
        #expect(agent.standardOutPath?.contains("Logs/Palilogy") == true)
    }

    @Test func labelCollisionGetsCounterSuffix() throws {
        let agent = try #require(CronConversion.agent(
            for: entry,
            existingLabels: ["com.inklinglabs.palilogy.backup-sh", "com.inklinglabs.palilogy.backup-sh-2"]
        ))
        #expect(agent.label == "com.inklinglabs.palilogy.backup-sh-3")
    }

    @Test func unparseableScheduleIsNotConvertible() {
        let rebootEntry = CronEntry(
            id: 1, scheduleExpression: "@reboot", command: "/usr/bin/true", raw: "@reboot /usr/bin/true"
        )
        #expect(CronConversion.agent(for: rebootEntry, existingLabels: []) == nil)
    }
}

struct CrontabRemovalTests {
    @Test func removesExactLineOnly() {
        let text = "MAILTO=x\n0 5 * * 1 /bin/a\n0 5 * * 1 /bin/b\n"
        let updated = CrontabService.removing(line: "0 5 * * 1 /bin/a", from: text)
        #expect(updated == "MAILTO=x\n0 5 * * 1 /bin/b\n")
    }

    @Test func missingLineReturnsNil() {
        #expect(CrontabService.removing(line: "0 * * * * /bin/x", from: "# empty\n") == nil)
    }
}

struct ConvertedFlagTests {
    @Test func convertedOnlyWhileJobExists() {
        let raw = "0 5 * * 1 /bin/a"
        let mapping = [raw: "com.inklinglabs.palilogy.a"]
        #expect(AppState.isConverted(
            raw: raw, mapping: mapping, existingLabels: ["com.inklinglabs.palilogy.a"]
        ))
        #expect(!AppState.isConverted(raw: raw, mapping: mapping, existingLabels: []))
        #expect(!AppState.isConverted(raw: raw, mapping: [:], existingLabels: ["com.inklinglabs.palilogy.a"]))
    }
}
