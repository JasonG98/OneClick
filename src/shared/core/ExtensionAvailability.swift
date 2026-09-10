import Foundation

/// What the settings window can honestly say about the Finder extension.
///
/// The system toggle and a live extension process are different facts. Finder
/// starts the extension once and never revives it if that process exits: during
/// development every rebuild replaces the `.appex` underneath the running
/// process, so the extension disappears while System Settings still reports it
/// as enabled. Reporting the toggle alone made the window claim "已启用" with no
/// menu anywhere in Finder and no hint about what to do.
enum ExtensionAvailability: Equatable {
    case disabled
    case enabled
    case enabledNotRunning
}

/// Decides which of those three states is true.
///
/// `heartbeat` is what the extension last wrote about itself. It is only
/// recorded while the extension is alive, so a fresh timestamp plus a process
/// that still exists means the menu really is reachable.
struct ExtensionAvailabilityEvaluator {
    /// A live extension process is the strong signal; this only backstops a
    /// recycled process identifier. It has to be long, because Finder asks for
    /// menus only when the user interacts: an idle machine can leave a perfectly
    /// healthy extension without a fresh heartbeat for hours.
    static let notRunningGrace: TimeInterval = 600

    var isEnabled: Bool
    var heartbeat: ExtensionHeartbeat?
    var isRunning: (ExtensionHeartbeat) -> Bool
    var now: () -> Date

    func evaluate() -> ExtensionAvailability {
        guard isEnabled else { return .disabled }
        guard let heartbeat, isRunning(heartbeat) else { return .enabledNotRunning }
        guard now().timeIntervalSince(heartbeat.recordedAt) <= Self.notRunningGrace else {
            return .enabledNotRunning
        }
        return .enabled
    }
}

/// The extension's periodic note to the settings window that it is alive.
struct ExtensionHeartbeat: Codable, Equatable, Sendable {
    var processIdentifier: Int32
    var bundleIdentifier: String
    var recordedAt: Date

    static let fileName = "extension-heartbeat.json"
}
