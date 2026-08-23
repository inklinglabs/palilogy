import Foundation
import Testing
@testable import HelpMeCronda

struct LaunchAgentCodecTests {
    @Test func roundTripFullAgent() throws {
        var agent = LaunchAgent(label: "com.inklinglabs.helpmecronda.backup")
        agent.programArguments = ["/bin/zsh", "-c", "backup.sh"]
        agent.runAtLoad = true
        agent.disabled = false
        agent.startCalendarInterval = [
            CalendarRule(minute: 0, hour: 5, weekday: 1),
            CalendarRule(minute: 0, hour: 5, weekday: 5),
        ]
        agent.standardOutPath = "/tmp/out.log"
        agent.standardErrorPath = "/tmp/err.log"
        agent.workingDirectory = "/Users/x"
        agent.environmentVariables = ["PATH": "/usr/bin"]
        agent.helpMeCrondaManaged = true

        let decoded = try LaunchAgentCodec.decode(LaunchAgentCodec.encode(agent))
        #expect(decoded == agent)
        #expect(decoded.isManaged)
        #expect(decoded.schedule == .calendar(agent.startCalendarInterval!))
    }

    @Test func roundTripIntervalAgent() throws {
        var agent = LaunchAgent(label: "com.example.tick")
        agent.programArguments = ["/usr/bin/true"]
        agent.startInterval = 900

        let decoded = try LaunchAgentCodec.decode(LaunchAgentCodec.encode(agent))
        #expect(decoded == agent)
        #expect(decoded.schedule == .interval(seconds: 900))
    }

    @Test func decodesSingleDictCalendarInterval() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
            <key>Label</key><string>com.example.daily</string>
            <key>ProgramArguments</key><array><string>/usr/bin/true</string></array>
            <key>StartCalendarInterval</key>
            <dict><key>Hour</key><integer>5</integer><key>Minute</key><integer>0</integer></dict>
        </dict></plist>
        """
        let agent = try LaunchAgentCodec.decode(Data(plist.utf8))
        #expect(agent.startCalendarInterval == [CalendarRule(minute: 0, hour: 5)])
    }

    @Test func toleratesForeignKeysAndIsNotManaged() throws {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
            <key>Label</key><string>com.google.keystone.agent</string>
            <key>Program</key><string>/opt/keystone/agent</string>
            <key>MachServices</key><dict><key>com.google.keystone.svc</key><true/></dict>
            <key>LimitLoadToSessionType</key><string>Aqua</string>
        </dict></plist>
        """
        let agent = try LaunchAgentCodec.decode(Data(plist.utf8))
        #expect(agent.label == "com.google.keystone.agent")
        #expect(!agent.isManaged)
        #expect(agent.command == ["/opt/keystone/agent"])
        #expect(agent.schedule == nil)
    }

    @Test func missingLabelFailsToDecode() {
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
            <key>Program</key><string>/usr/bin/true</string>
        </dict></plist>
        """
        #expect(throws: (any Error).self) {
            _ = try LaunchAgentCodec.decode(Data(plist.utf8))
        }
    }

    @Test func programArgumentsWinOverProgramInCommand() throws {
        var agent = LaunchAgent(label: "com.example.both")
        agent.program = "/bin/ignored"
        agent.programArguments = ["/bin/zsh", "-c", "echo hi"]
        #expect(agent.command == ["/bin/zsh", "-c", "echo hi"])
    }
}
