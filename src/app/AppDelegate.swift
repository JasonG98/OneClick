import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = SettingsModel()
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "requests")

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let id = OpenRequestLink.requestID(for: url) else { continue }
            Task { @MainActor in
                do {
                    let repository = OpenRequestRepository(directory: try SharedEnvironment.containerURL())
                    let handler = OpenRequestHandler(requests: repository, settings: try SharedEnvironment.repository())
                    try await handler.open(id)
                    logger.info("Completed Finder open request")
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
