import Foundation

@MainActor
struct OpenRequestHandler {
    let requests: OpenRequestRepository
    let settings: SettingsRepository
    var executor = ActionExecutor()

    func open(_ id: UUID) async throws {
        let request = try requests.consume(id: id)
        let current = try settings.load()
        guard let target = current.targets.first(where: { $0.id == request.targetID && $0.isEnabled }) else {
            throw PlatformError.applicationUnavailable(request.targetID)
        }
        let selection = SelectionContext(selected: request.urls, targeted: nil, isContainer: false)
        try await executor.open(target, selection: selection)
    }
}
