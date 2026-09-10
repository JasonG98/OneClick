import Foundation
import Testing
@testable import OneClickCore

@Test func terminalIsTheOnlyBuiltInTarget() throws {
    #expect(OpenTarget.builtIns.count == 1)
    let target = try #require(OpenTarget.builtIns.first)
    #expect(target.id == "terminal")
    #expect(target.name == "Terminal")
    #expect(target.kind == .terminal)
    #expect(target.bundleIdentifier == "com.apple.Terminal")
    #expect(target.applicationURL == nil)
    #expect(target.isEnabled)
}

@Test func initialSettingsMonitorTheRealHomeDirectory() {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let settings = Settings.initial(home: home)

    #expect(settings.version == 1)
    #expect(settings.targets == OpenTarget.builtIns)
    #expect(settings.directories == [home])
}

/// A configuration written before a target kind was retired must still decode.
/// Failing here would surface as "配置已损坏" and leave the menu permanently
/// broken, instead of letting the load migration drop the preset.
@Test func retiredTargetKindDecodesAsAPlainApplication() throws {
    let json = Data(#"""
    {"id":"claude","name":"Claude Code","kind":"claude","bundleIdentifier":"com.anthropic.claude-code-url-handler","isEnabled":true}
    """#.utf8)

    let target = try JSONDecoder().decode(OpenTarget.self, from: json)
    #expect(target.kind == .application)
    #expect(target.id == "claude")
}
