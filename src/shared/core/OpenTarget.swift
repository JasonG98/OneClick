import Foundation

enum TargetKind: String, Codable, Sendable {
    case application
    case terminal
    case claude
}

struct OpenTarget: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var kind: TargetKind
    var bundleIdentifier: String?
    var applicationURL: URL?
    var isEnabled: Bool

    static let builtIns: [OpenTarget] = [
        OpenTarget(
            id: "claude",
            name: "Claude Code",
            kind: .claude,
            bundleIdentifier: "com.anthropic.claude-code-url-handler",
            applicationURL: nil,
            isEnabled: true
        ),
    ]
}

struct Settings: Codable, Equatable, Sendable {
    var version: Int = 1
    var targets: [OpenTarget] = OpenTarget.builtIns
    var copiesPaths: Bool = true
    var directories: [URL] = []

    static func initial(home: URL) -> Settings {
        Settings(directories: [home])
    }
}
