import AppKit
import OSLog

@MainActor
struct ActionExecutor {
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "actions")

    func open(_ target: OpenTarget, selection: SelectionContext) async throws {
        guard !selection.urls.isEmpty else { throw PlatformError.emptySelection }
        guard let application = ApplicationResolver().applicationURL(for: target) else {
            throw PlatformError.applicationUnavailable(target.name)
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        switch target.kind {
        case .application:
            // Validate at click time: a file may have moved since the menu was built.
            for url in selection.urls {
                _ = try url.resourceValues(forKeys: [.isDirectoryKey])
            }
            _ = try await NSWorkspace.shared.open(selection.urls, withApplicationAt: application, configuration: configuration)
        case .terminal:
            let directories = try selection.workingDirectories()
            _ = try await NSWorkspace.shared.open(directories, withApplicationAt: application, configuration: configuration)
        case .claude:
            let links = try selection.workingDirectories().map { try ClaudeLink.make(directory: $0) }
            for link in links {
                _ = try await NSWorkspace.shared.open(link, configuration: configuration)
            }
        }
        logger.info("Opened target \(target.id, privacy: .public), selection count \(selection.urls.count)")
    }

    func copyPaths(_ selection: SelectionContext) throws {
        guard !selection.urls.isEmpty else { throw PlatformError.emptySelection }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        guard pasteboard.setString(selection.pathText, forType: .string) else {
            throw PlatformError.clipboardUnavailable
        }
        logger.info("Copied \(selection.urls.count) paths")
    }

    func presentFailure(_ error: Error) {
        logger.error("Action failed: \(error.localizedDescription, privacy: .public)")
        SharedEnvironment.report(error)
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SharedEnvironment.appIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: app, configuration: .init()) { _, _ in }
        DistributedNotificationCenter.default().postNotificationName(SharedEnvironment.errorOccurred, object: nil, userInfo: nil, deliverImmediately: true)
    }
}
