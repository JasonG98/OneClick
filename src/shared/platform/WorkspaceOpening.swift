import AppKit

/// Only the operating-system boundary is replaceable; routing and validation
/// remain in ActionExecutor.
@MainActor
protocol WorkspaceOpening {
    func applicationURL(for target: OpenTarget) -> URL?
    func open(_ urls: [URL], withApplicationAt application: URL) async throws
    func openApplication(_ application: URL) async throws
}

@MainActor
struct SystemWorkspace: WorkspaceOpening {
    func applicationURL(for target: OpenTarget) -> URL? {
        ApplicationResolver().applicationURL(for: target)
    }

    func open(_ urls: [URL], withApplicationAt application: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.open(urls, withApplicationAt: application, configuration: configuration)
    }

    func openApplication(_ application: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await NSWorkspace.shared.openApplication(at: application, configuration: configuration)
    }
}
