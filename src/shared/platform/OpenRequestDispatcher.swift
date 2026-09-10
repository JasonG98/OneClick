import AppKit

@MainActor
struct OpenRequestDispatcher {
    var repository: () throws -> OpenRequestRepository = {
        OpenRequestRepository(directory: try SharedEnvironment.containerURL())
    }
    var workspace: any WorkspaceOpening = SystemWorkspace()

    func open(_ target: OpenTarget, selection: SelectionContext) async throws {
        let repository = try repository()
        let id = try repository.enqueue(targetID: target.id, urls: selection.urls)
        do {
            try await workspace.open(OpenRequestLink.make(requestID: id), activates: false)
        } catch {
            _ = try? repository.consume(id: id)
            throw error
        }
    }
}
