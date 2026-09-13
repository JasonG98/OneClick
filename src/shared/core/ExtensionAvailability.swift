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
/// `isRunning` is the only evidence, because it is the only evidence that cannot
/// go stale: the process registry either names a live extension process or it
/// does not.
struct ExtensionAvailabilityEvaluator {
    var isEnabled: Bool
    var isRunning: () -> Bool

    func evaluate() -> ExtensionAvailability {
        guard isEnabled else { return .disabled }
        return isRunning() ? .enabled : .enabledNotRunning
    }
}
