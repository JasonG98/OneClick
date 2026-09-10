import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var model = SettingsModel()
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "settings")

    private var presentSettings: (() -> Void)?

    /// Installed by the settings scene once SwiftUI can open windows. The scene
    /// presents itself on launch, and a reopen request always arrives after the
    /// scene is built, so there is no pending/replay state to carry.
    func installSettingsPresenter(_ present: @escaping () -> Void) {
        presentSettings = present
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        logger.info("Settings requested by application reopen")
        presentSettings?()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
}
