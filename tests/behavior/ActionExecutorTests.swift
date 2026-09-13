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
        try await ActionExecutor(workspace: workspace).open(sampleTargets[0], selection: selection([second, first]))
        #expect(workspace.files == [.init(urls: [second, first], application: URL(fileURLWithPath: "/Applications/Test Editor.app"))])
    }

    @Test func terminalOpensDistinctParentDirectories() async throws {
        let files = try TemporaryFiles()
        let first = try files.file("one")
        let second = try files.file("two")
        let folder = try files.directory("中文 + # & ' folder")
        let workspace = RecordingWorkspace()
        try await ActionExecutor(workspace: workspace).open(sampleTargets[3], selection: selection([first, second, folder]))
        #expect(workspace.files.count == 1)
        #expect(workspace.files.first?.urls == [files.root, folder])
    }

    @Test func invalidSelectionsAndUnavailableAppsNeverReachWorkspace() async throws {
        let workspace = RecordingWorkspace()
        let executor = ActionExecutor(workspace: workspace)
        await #expect(throws: PlatformError.emptySelection) { try await executor.open(sampleTargets[0], selection: selection([])) }
        await #expect(throws: (any Error).self) { try await executor.open(sampleTargets[0], selection: selection([URL(fileURLWithPath: "/oneclick-tests-missing/\(UUID())")])) }
        workspace.application = nil
        // 报错用应用自己的全名，不是菜单里的短名：用户要在设置窗口里按这个名字
        // 找到那个应用。别名只作用于菜单文案（见 ApplicationAliasTests 与 AGENTS.md）。
        await #expect(throws: PlatformError.applicationUnavailable("Visual Studio Code")) { try await executor.open(sampleTargets[0], selection: selection([URL(fileURLWithPath: "/tmp")])) }
        #expect(workspace.files.isEmpty)
    }

    @Test func workspaceFailurePropagatesToCaller() async throws {
        let files = try TemporaryFiles()
        let url = try files.file("a")
        let workspace = RecordingWorkspace()
        workspace.failure = .unavailable
        await #expect(throws: TestFailure.unavailable) { try await ActionExecutor(workspace: workspace).open(sampleTargets[0], selection: selection([url])) }
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

    @Test func copyingRefusesASelectionWhoseNameContainsALineBreak() throws {
        var writes: [String] = []
        let executor = ActionExecutor(workspace: RecordingWorkspace(), writeClipboard: { writes.append($0); return true })
        // 文件名里的换行是合法的，而剪贴板格式用它当分隔符：注入的那一行会
        // 冒充一条用户没选过的路径。要保的性质是它从未到达剪贴板。
        let injected = URL(fileURLWithPath: "/tmp/report\nrm -rf ~")

        #expect(throws: (any Error).self) { try executor.copyPaths(selection([injected])) }
        #expect(writes.isEmpty)
    }

    @Test func openingStillAcceptsANameContainingALineBreak() async throws {
        let files = try TemporaryFiles()
        let url = try files.file("a\nb.txt")
        let workspace = RecordingWorkspace()

        try await ActionExecutor(workspace: workspace).open(sampleTargets[0], selection: selection([url]))
        #expect(workspace.files.first?.urls == [url])
    }
}
