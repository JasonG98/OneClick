import AppKit

/// Only the operating-system boundary is replaceable; routing and validation
/// remain in ActionExecutor and the request handlers.
@MainActor
protocol WorkspaceOpening {
    func applicationURL(for target: OpenTarget) -> URL?
    func open(_ urls: [URL], withApplicationAt application: URL) async throws
    func open(_ url: URL, activates: Bool) async throws
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

    func open(_ url: URL, activates: Bool) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = activates
        _ = try await NSWorkspace.shared.open(url, configuration: configuration)
    }
}
