import Foundation

enum TargetKind: String, Codable, Sendable {
    case application
    case terminal

    /// Retired kinds decode as a plain application so a configuration written by
    /// an older version can still be read. The load migration then drops the
    /// retired preset instead of failing the whole file, which would leave the
    /// user with a menu that never appears again.
    init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = TargetKind(rawValue: raw) ?? .application
    }
}

struct OpenTarget: Codable, Identifiable, Equatable, Sendable {
    var id: String
    var name: String
    var kind: TargetKind
    var bundleIdentifier: String?
    var applicationURL: URL?
    var isEnabled: Bool

    /// Terminal is the only built-in target; every other application is imported
    /// by the user from `/Applications`.
    static let builtIns: [OpenTarget] = [
        OpenTarget(
            id: "terminal",
            name: "Terminal",
            kind: .terminal,
            bundleIdentifier: "com.apple.Terminal",
            applicationURL: nil,
            isEnabled: true
        ),
    ]
}

struct Settings: Codable, Equatable, Sendable {
    var version: Int = 1
    var targets: [OpenTarget] = OpenTarget.builtIns
    var directories: [URL] = []

    static func initial(home: URL) -> Settings {
        Settings(directories: [home])
    }
}
