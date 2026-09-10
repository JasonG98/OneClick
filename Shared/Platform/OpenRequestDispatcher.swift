import AppKit

@MainActor
struct OpenRequestDispatcher {
    func open(_ target: OpenTarget, selection: SelectionContext) async throws {
        let repository = OpenRequestRepository(directory: try SharedEnvironment.containerURL())
        let id = try repository.enqueue(targetID: target.id, urls: selection.urls)
        var components = URLComponents()
        components.scheme = "oneclick"
        components.host = "open"
        components.queryItems = [URLQueryItem(name: "request", value: id.uuidString)]
        guard let url = components.url else { throw PlatformError.emptySelection }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        do {
            _ = try await NSWorkspace.shared.open(url, configuration: configuration)
        } catch {
            _ = try? repository.consume(id: id)
            throw error
        }
    }
}
