import Foundation
import Testing
@testable import OneClickCore

@Suite @MainActor
struct OpenFlowTests {
    @Test func finderRequestReachesHostExactlyOnce() async throws {
        let files = try TemporaryFiles()
        let url = try files.file("中文 + # & ' demo")
        try files.settings.save(Settings())
        let workspace = RecordingWorkspace()
        try await OpenRequestDispatcher(repository: { files.requests }, workspace: workspace).open(OpenTarget.builtIns[0], selection: selection([url]))
        let link = try #require(workspace.links.first)
        #expect(!link.activates)
        let id = try #require(OpenRequestLink.requestID(for: link.url))
        let handler = OpenRequestHandler(requests: files.requests, settings: files.settings, executor: ActionExecutor(workspace: workspace))
        try await handler.open(id)
        #expect(workspace.files.first?.urls == [url])
        await #expect(throws: (any Error).self) { try await handler.open(id) }
        #expect(workspace.files.count == 1)
    }

    @Test func failedHostLaunchRemovesPendingRequest() async throws {
        let files = try TemporaryFiles()
        let workspace = RecordingWorkspace()
        workspace.failure = .unavailable
        await #expect(throws: TestFailure.unavailable) {
            try await OpenRequestDispatcher(repository: { files.requests }, workspace: workspace).open(OpenTarget.builtIns[3], selection: selection([files.root]))
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: files.root.path).isEmpty)
    }

    @Test(arguments: ["disabled", "removed"])
    func hostRechecksTargetAfterMenuWasCreated(change: String) async throws {
        let files = try TemporaryFiles()
        let id = try files.requests.enqueue(targetID: "vscode", urls: [files.root])
        var settings = Settings()
        if change == "disabled" { settings.targets[0].isEnabled = false }
        else { settings.targets.removeFirst() }
        try files.settings.save(settings)
        let workspace = RecordingWorkspace()
        let handler = OpenRequestHandler(requests: files.requests, settings: files.settings, executor: ActionExecutor(workspace: workspace))
        await #expect(throws: PlatformError.applicationUnavailable("vscode")) { try await handler.open(id) }
        #expect(workspace.files.isEmpty)
        #expect(throws: (any Error).self) { try files.requests.consume(id: id) }
    }

    @Test(arguments: [
        "https://open?request=ID", "oneclick://other?request=ID", "oneclick://open/path?request=ID",
        "oneclick://user@open?request=ID", "oneclick://user:password@open?request=ID",
        "oneclick://open:123?request=ID", "oneclick://open?request=ID#fragment",
        "oneclick://open?request=ID&request=ID", "oneclick://open?request=ID&command=ls",
        "oneclick://open?other=ID", "oneclick://open?request=not-a-uuid", "oneclick://open", "oneclick://open?request"
    ])
    func malformedLinksAreIgnored(value: String) throws {
        let string = value.replacingOccurrences(of: "ID", with: "12345678-1234-1234-1234-123456789ABC")
        #expect(OpenRequestLink.requestID(for: try #require(URL(string: string))) == nil)
    }

    @Test func validExternalLinkUsesOnlyTheRequestIdentifier() throws {
        let url = try #require(URL(string: "oneclick://open?request=12345678-1234-1234-1234-123456789ABC"))
        #expect(OpenRequestLink.requestID(for: url)?.uuidString == "12345678-1234-1234-1234-123456789ABC")
    }
}
