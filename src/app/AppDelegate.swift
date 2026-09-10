import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Background URL requests do not need to initialize the settings UI model.
    lazy var model = SettingsModel()
    var showSettings: () -> Void = {}
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "requests")

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        logger.info("Settings requested by ordinary launch")
        showSettings()
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        logger.info("Settings requested by application reopen")
        showSettings()
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let id = OpenRequestLink.requestID(for: url) else { continue }
            Task { @MainActor in
                do {
                    let repository = OpenRequestRepository(directory: try SharedEnvironment.containerURL())
                    let handler = OpenRequestHandler(requests: repository, settings: try SharedEnvironment.repository())
                    try await handler.open(id)
                    let visibleWindows = application.windows.filter(\.isVisible).count
                    logger.info("Completed Finder open request; visible windows: \(visibleWindows), active: \(application.isActive)")
                } catch {
                    logger.error("Open request failed: \(error.localizedDescription, privacy: .public)")
                    let alert = NSAlert()
                    alert.messageText = "操作未完成"
                    alert.informativeText = error.localizedDescription
                    alert.addButton(withTitle: "好")
                    NSApp.activate()
                    alert.runModal()
                }
            }
        }
    }
}
