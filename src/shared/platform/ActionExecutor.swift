import AppKit
import OSLog

@MainActor
struct ActionExecutor {
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "actions")
    private let workspace: any WorkspaceOpening
    private let writeClipboard: (String) -> Bool

    init(workspace: any WorkspaceOpening = SystemWorkspace(), writeClipboard: @escaping (String) -> Bool = { text in
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(text, forType: .string)
    }) {
        self.workspace = workspace
        self.writeClipboard = writeClipboard
    }

    /// Runs inside the Finder extension: every target is opened here, with no
    /// hand-off to the container app.
    func open(_ target: OpenTarget, selection: SelectionContext) async throws {
        guard !selection.urls.isEmpty else { throw PlatformError.emptySelection }
        guard let application = workspace.applicationURL(for: target) else {
            throw PlatformError.applicationUnavailable(target.name)
        }
        switch target.kind {
        case .application:
            // Validate at click time: a file may have moved since the menu was built.
            for url in selection.urls {
                _ = try url.resourceValues(forKeys: [.isDirectoryKey])
            }
            try await workspace.open(selection.urls, withApplicationAt: application)
        case .terminal:
            let directories = try selection.workingDirectories()
            try await workspace.open(directories, withApplicationAt: application)
        }
        logger.info("Opened target \(target.id, privacy: .public), selection count \(selection.urls.count)")
    }

    func copyPaths(_ selection: SelectionContext) throws {
        guard !selection.urls.isEmpty else { throw PlatformError.emptySelection }
        guard writeClipboard(selection.pathText) else {
            throw PlatformError.clipboardUnavailable
        }
        logger.info("Copied \(selection.urls.count) paths")
    }

    /// Surfaces a failure in the settings window. The extension has no UI of its
    /// own, so the container app is brought up to show it.
    func presentFailure(_ error: Error) {
        logger.error("Action failed: \(error.localizedDescription, privacy: .public)")
        SharedEnvironment.report(error)
        guard let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SharedEnvironment.appIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: app, configuration: .init()) { _, _ in }
        DistributedNotificationCenter.default().postNotificationName(SharedEnvironment.errorOccurred, object: nil, userInfo: nil, deliverImmediately: true)
    }
}
