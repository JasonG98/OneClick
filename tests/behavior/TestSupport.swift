import AppKit
import Testing
@testable import OneClickCore

final class TemporaryFiles {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("OneClickTests-\(UUID())", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    func file(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name)
        try Data("fixture".utf8).write(to: url)
        return url
    }

    func directory(_ name: String) throws -> URL {
        let url = root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func application(_ name: String, identifier: String) throws -> URL {
        let url = try directory("\(name).app")
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": identifier, "CFBundleName": name], format: .xml, options: 0)
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return url
    }

    var settings: SettingsRepository { SettingsRepository(fileURL: root.appendingPathComponent("settings.json")) }
}

enum TestFailure: Error, Equatable { case unavailable }

@MainActor
final class RecordingWorkspace: WorkspaceOpening {
    struct FileOpen: Equatable {
        let urls: [URL]
        let application: URL
    }
    var application: URL? = URL(fileURLWithPath: "/Applications/Test Editor.app")
    var failure: TestFailure?
    var files: [FileOpen] = []

    func applicationURL(for target: OpenTarget) -> URL? { application }

    func open(_ urls: [URL], withApplicationAt application: URL) async throws {
        if let failure { throw failure }
        files.append(FileOpen(urls: urls, application: application))
    }

    func openApplication(_ application: URL) async throws {}
}

@MainActor
final class SettingsHarness {
    let files: TemporaryFiles
    var availableIDs: Set<String> = ["test-terminal", "test-vscode"]
    var extensionEnabled = false
    var extensionRunning = false
    var reloadSucceeds = true
    var reloadCount = 0
    var notifications = 0

    init() throws { files = try TemporaryFiles() }

    func model() -> SettingsModel {
        SettingsModel(services: SettingsServices(
            repository: { self.files.settings },
            homeDirectory: files.root,
            applicationURL: { self.availableIDs.contains($0.id) ? URL(fileURLWithPath: "/Applications/Test.app") : nil },
            extensionAvailability: {
                ExtensionAvailabilityEvaluator(
                    isEnabled: self.extensionEnabled,
                    isRunning: { self.extensionRunning }
                ).evaluate()
            },
            reloadExtension: {
                self.reloadCount += 1
                return self.reloadSucceeds
            },
            settingsChanged: { self.notifications += 1 },
            takeError: { nil },
            presentError: {}
        ))
    }
}

func selection(_ urls: [URL]) -> SelectionContext {
    SelectionContext(selected: urls, targeted: nil, isContainer: false)
}

// Explicit fixtures, independent of what ships built in, so tests control
// availability, ordering and count without depending on the defaults.
let sampleTargets: [OpenTarget] = [
        OpenTarget(
            id: "test-vscode",
            name: "Visual Studio Code",
            kind: .application,
            bundleIdentifier: "com.microsoft.VSCode",
            applicationURL: nil,
            isEnabled: true
        ),
        OpenTarget(
            id: "test-cursor",
            name: "Cursor",
            kind: .application,
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            applicationURL: nil,
            isEnabled: true
        ),
        OpenTarget(
            id: "test-sublime",
            name: "Sublime Text",
            kind: .application,
            bundleIdentifier: "com.sublimetext.4",
            applicationURL: nil,
            isEnabled: true
        ),
        OpenTarget(
            id: "test-terminal",
            name: "Terminal",
            kind: .terminal,
            bundleIdentifier: "com.apple.Terminal",
            applicationURL: nil,
            isEnabled: true
        ),
        OpenTarget(
            id: "test-nova",
            name: "Nova",
            kind: .application,
            bundleIdentifier: "com.panic.Nova",
            applicationURL: nil,
            isEnabled: true
        ),
]
