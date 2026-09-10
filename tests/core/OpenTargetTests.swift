import Foundation
import Testing
@testable import OneClickCore

@Test func onlyClaudeCodeIsIncludedByDefault() throws {
    #expect(OpenTarget.builtIns.count == 1)
    let target = try #require(OpenTarget.builtIns.first)
    #expect(target.id == "claude")
    #expect(target.name == "Claude Code")
    #expect(target.kind == .claude)
    #expect(target.bundleIdentifier == "com.anthropic.claude-code-url-handler")
    #expect(target.applicationURL == nil)
    #expect(target.isEnabled)
}

@Test func initialSettingsMonitorTheRealHomeDirectory() {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let settings = Settings.initial(home: home)

    #expect(settings.version == 1)
    #expect(settings.targets == OpenTarget.builtIns)
    #expect(settings.copiesPaths)
    #expect(settings.directories == [home])
}
