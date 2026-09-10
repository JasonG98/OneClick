import Foundation
import Testing
@testable import OneClickCore

@Suite @MainActor
struct ActionExecutorTests {
    @Test func editorReceivesOriginalFilesInOrder() async throws {
        let files = try TemporaryFiles()
        let first = try files.file("中文 + # & ' file.swift")
        let second = try files.file("second.swift")
        let workspace = RecordingWorkspace()
        try await ActionExecutor(workspace: workspace).open(OpenTarget.builtIns[0], selection: selection([second, first]))
        #expect(workspace.files == [.init(urls: [second, first], application: URL(fileURLWithPath: "/Applications/Test Editor.app"))])
        #expect(workspace.links.isEmpty)
    }

    @Test func terminalOpensDistinctParentDirectories() async throws {
        let files = try TemporaryFiles()
        let first = try files.file("one")
        let second = try files.file("two")
        let folder = try files.directory("中文 + # & ' folder")
        let workspace = RecordingWorkspace()
        try await ActionExecutor(workspace: workspace).open(OpenTarget.builtIns[3], selection: selection([first, second, folder]))
        #expect(workspace.files.count == 1)
        #expect(workspace.files.first?.urls == [files.root, folder])
        #expect(workspace.links.isEmpty)
    }

    @Test func claudeUsesOneDeepLinkPerDirectoryWithoutOpeningFiles() async throws {
        let files = try TemporaryFiles()
        let folder = try files.directory("C++ + 中文")
        let workspace = RecordingWorkspace()
        try await ActionExecutor(workspace: workspace).open(OpenTarget.builtIns[4], selection: selection([folder, folder]))
        #expect(workspace.files.isEmpty)
        let call = try #require(workspace.links.first)
        #expect(workspace.links.count == 1)
        #expect(call.activates)
        #expect(call.url.scheme == "claude-cli")
        #expect(call.url.host == "open")
        #expect(!call.url.absoluteString.contains("+"))
        #expect(URLComponents(url: call.url, resolvingAgainstBaseURL: false)?.queryItems == [URLQueryItem(name: "cwd", value: folder.path)])
    }

    @Test func invalidSelectionsAndUnavailableAppsNeverReachWorkspace() async throws {
        let workspace = RecordingWorkspace()
        let executor = ActionExecutor(workspace: workspace)
        await #expect(throws: PlatformError.emptySelection) { try await executor.open(OpenTarget.builtIns[0], selection: selection([])) }
        await #expect(throws: (any Error).self) { try await executor.open(OpenTarget.builtIns[0], selection: selection([URL(fileURLWithPath: "/oneclick-tests-missing/\(UUID())")])) }
        workspace.application = nil
        await #expect(throws: PlatformError.applicationUnavailable("Visual Studio Code")) { try await executor.open(OpenTarget.builtIns[0], selection: selection([URL(fileURLWithPath: "/tmp")])) }
        #expect(workspace.files.isEmpty)
        #expect(workspace.links.isEmpty)
    }

    @Test func workspaceFailurePropagatesToCaller() async throws {
        let files = try TemporaryFiles()
        let url = try files.file("a")
        let workspace = RecordingWorkspace()
        workspace.failure = .unavailable
        await #expect(throws: TestFailure.unavailable) { try await ActionExecutor(workspace: workspace).open(OpenTarget.builtIns[0], selection: selection([url])) }
    }

    @Test func copyingWritesExactPathsAndReportsClipboardFailure() throws {
        var writes: [String] = []
        let executor = ActionExecutor(workspace: RecordingWorkspace(), writeClipboard: { writes.append($0); return true })
        try executor.copyPaths(selection([URL(fileURLWithPath: "/tmp/中文 + # & ' a"), URL(fileURLWithPath: "/tmp/b")]))
        #expect(writes == ["/tmp/中文 + # & ' a\n/tmp/b"])
        #expect(throws: PlatformError.emptySelection) { try executor.copyPaths(selection([])) }
        #expect(writes.count == 1)
        let failing = ActionExecutor(workspace: RecordingWorkspace(), writeClipboard: { _ in false })
        #expect(throws: PlatformError.clipboardUnavailable) { try failing.copyPaths(selection([URL(fileURLWithPath: "/tmp/a")])) }
    }
}
