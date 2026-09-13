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

    /// Closing the settings window quits the app.
    ///
    /// The window is the whole product surface here: every action runs in the
    /// Finder extension, and there is no background work left for the app to do
    /// once it is closed. Staying alive only left a Dock icon and a running
    /// process behind a window the user had already dismissed. Reopening still
    /// works -- launching the app again presents the window, and the extension
    /// relaunches it by bundle id when settings are requested from Finder.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
