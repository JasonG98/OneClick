import AppKit
import OSLog

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = SettingsModel()
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "requests")

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "oneclick", url.host == "open",
                  url.path.isEmpty, url.user == nil, url.password == nil, url.port == nil,
                  url.fragment == nil,
                  let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
                  items.count == 1, items[0].name == "request",
                  let rawID = items[0].value, let id = UUID(uuidString: rawID) else { continue }
            Task { @MainActor in
                do {
                    let repository = OpenRequestRepository(directory: try SharedEnvironment.containerURL())
                    let request = try repository.consume(id: id)
                    let settings = try SharedEnvironment.repository().load()
                    guard let target = settings.targets.first(where: { $0.id == request.targetID && $0.isEnabled }) else {
                        throw PlatformError.applicationUnavailable(request.targetID)
                    }
                    let selection = SelectionContext(selected: request.urls, targeted: nil, isContainer: false)
                    try await ActionExecutor().open(target, selection: selection)
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
