import Foundation
import Testing
@testable import OneClickCore

@Test func builtInTargetsHaveStableRoutingIdentifiers() throws {
    let routes = OpenTarget.builtIns.map {
        ($0.id, $0.name, $0.kind, $0.bundleIdentifier, $0.applicationURL, $0.isEnabled)
    }

    #expect(routes.count == 5)
    #expect(routes[0].0 == "vscode")
    #expect(routes[0].1 == "Visual Studio Code")
    #expect(routes[0].2 == .application)
    #expect(routes[0].3 == "com.microsoft.VSCode")
    #expect(routes[0].4 == nil)
    #expect(routes[0].5)
    #expect(routes[1].0 == "cursor")
    #expect(routes[1].3 == "com.todesktop.230313mzl4w4u92")
    #expect(routes[2].0 == "sublime")
    #expect(routes[2].3 == "com.sublimetext.4")
    #expect(routes[3].0 == "terminal")
    #expect(routes[3].2 == .terminal)
    #expect(routes[3].3 == "com.apple.Terminal")
    #expect(routes[4].0 == "claude")
    #expect(routes[4].2 == .claude)
    #expect(routes[4].3 == "com.anthropic.claude-code-url-handler")
}

@Test func initialSettingsMonitorTheRealHomeDirectory() {
    let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)
    let settings = Settings.initial(home: home)

    #expect(settings.version == 1)
    #expect(settings.targets == OpenTarget.builtIns)
    #expect(settings.copiesPaths)
    #expect(settings.directories == [home])
}
