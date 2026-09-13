import Foundation
import Testing
@testable import OneClickCore

/// Upgrade path for a real install: a configuration written by an older version
/// holds retired presets whose `kind` no longer exists. It has to load, keep the
/// user's own applications and their switches, and drop only the presets.
@Test func loadingLegacyPresetsRemovesThemAndPreservesUserChoices() throws {
    try withRepositoryFixture { root, fileURL in
        let imported = root.appendingPathComponent("Code.app").absoluteString
        let legacy = Data(#"""
        {
          "version": 1,
          "targets": [
            {"id":"user-editor","name":"Visual Studio Code","kind":"application","bundleIdentifier":"com.microsoft.VSCode","applicationURL":"\#(imported)","isEnabled":true},
            {"id":"vscode","name":"Visual Studio Code","kind":"application","bundleIdentifier":"com.microsoft.VSCode","isEnabled":false},
            {"id":"sublime","name":"Sublime Text","kind":"application","bundleIdentifier":"com.sublimetext.4","isEnabled":true},
            {"id":"terminal","name":"Terminal","kind":"terminal","bundleIdentifier":"com.apple.Terminal","isEnabled":false},
            {"id":"claude","name":"Claude Code","kind":"claude","bundleIdentifier":"com.anthropic.claude-code-url-handler","isEnabled":true}
          ],
          "copiesPaths": false,
          "directories": ["\#(root.absoluteString)"]
        }
        """#.utf8)
        try legacy.write(to: fileURL)

        let repository = SettingsRepository(fileURL: fileURL)
        let loaded = try repository.load()

        // Imported application and the Terminal preset survive; the retired
        // vscode/sublime/claude presets do not. Terminal keeps its off switch.
        #expect(loaded.targets.map(\.id) == ["user-editor", "terminal"])
        #expect(loaded.targets[0].isEnabled)
        #expect(!loaded.targets[1].isEnabled)
        #expect(loaded.directories == [root])

        try repository.save(loaded)
        #expect(try repository.load() == loaded)
    }
}

/// A configuration that held nothing but retired presets would otherwise come
/// back empty; it falls back to the current built-ins instead.
@Test func configurationHoldingOnlyRetiredPresetsFallsBackToBuiltIns() throws {
    try withRepositoryFixture { _, fileURL in
        let legacy = Data(#"""
        {"version":1,"targets":[{"id":"claude","name":"Claude Code","kind":"claude","bundleIdentifier":"com.anthropic.claude-code-url-handler","isEnabled":true}],"directories":[]}
        """#.utf8)
        try legacy.write(to: fileURL)

        #expect(try SettingsRepository(fileURL: fileURL).load().targets == OpenTarget.builtIns)
    }
}

/// A configuration that predates the current built-ins gets them back while it
/// is being rewritten — the case for an install that had an imported editor
/// alongside the retired Claude preset.
@Test func migratingARetiredPresetAlsoRestoresAMissingBuiltIn() throws {
    try withRepositoryFixture { root, fileURL in
        let imported = root.appendingPathComponent("Code.app").absoluteString
        let legacy = Data(#"""
        {"version":1,"targets":[
          {"id":"user-editor","name":"Visual Studio Code","kind":"application","bundleIdentifier":"com.microsoft.VSCode","applicationURL":"\#(imported)","isEnabled":true},
          {"id":"claude","name":"Claude Code","kind":"claude","bundleIdentifier":"com.anthropic.claude-code-url-handler","isEnabled":true}
        ],"directories":[]}
        """#.utf8)
        try legacy.write(to: fileURL)

        #expect(try SettingsRepository(fileURL: fileURL).load().targets.map(\.id) == ["user-editor", "terminal"])
    }
}

/// A configuration with no retired presets is left exactly as the user left it
/// — nothing is added behind their back.
@Test func configurationWithoutRetiredPresetsIsNotModified() throws {
    try withRepositoryFixture { root, fileURL in
        let repository = SettingsRepository(fileURL: fileURL)
        let curated = Settings(targets: [
            OpenTarget(
                id: "user-editor",
                name: "Visual Studio Code",
                kind: .application,
                bundleIdentifier: "com.microsoft.VSCode",
                applicationURL: root.appendingPathComponent("Code.app"),
                isEnabled: true
            ),
        ])
        try repository.save(curated)

        #expect(try repository.load() == curated)
    }
}

@Test func missingSettingsReturnEmptyDirectoryDefaults() throws {
    try withRepositoryFixture { _, fileURL in
        let settings = try SettingsRepository(fileURL: fileURL).load()

        #expect(settings == Settings())
        #expect(settings.directories.isEmpty)
    }
}

@Test func savedSettingsRoundTripOrderAndSwitches() throws {
    try withRepositoryFixture { root, fileURL in
        let customApplication = root.appendingPathComponent("Nova.app", isDirectory: true)
        let custom = OpenTarget(
            id: "custom-nova",
            name: "Nova",
            kind: .application,
            bundleIdentifier: "com.panic.Nova",
            applicationURL: customApplication,
            isEnabled: false
        )
        let directory = root.appendingPathComponent("Workspace", isDirectory: true)
        var targets = OpenTarget.builtIns
        targets.insert(custom, at: 0)
        let expected = Settings(
            version: 1,
            targets: targets,
            directories: [directory]
        )

        try SettingsRepository(fileURL: fileURL).save(expected)
        let loaded = try SettingsRepository(fileURL: fileURL).load()

        #expect(loaded == expected)
    }
}

@Test func saveCreatesOnlyItsMissingParentDirectory() throws {
    try withRepositoryFixture { root, _ in
        let nestedFile = root
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent("settings.json")

        try SettingsRepository(fileURL: nestedFile).save(Settings())

        #expect(FileManager.default.fileExists(atPath: nestedFile.path))
    }
}

@Test func malformedSettingsThrowWithoutOverwritingPersistedBytes() throws {
    try withRepositoryFixture { _, fileURL in
        let malformed = Data(#"{"version":1,"targets": ["#.utf8)
        try malformed.write(to: fileURL)
        let repository = SettingsRepository(fileURL: fileURL)

        #expect(throws: (any Error).self) { try repository.load() }
        #expect(try Data(contentsOf: fileURL) == malformed)
    }
}

@Test func unsupportedVersionThrowsWithoutReplacingSettings() throws {
    try withRepositoryFixture { _, fileURL in
        let unsupported = Data(
            #"{"version":2,"targets":[],"copiesPaths":true,"directories":[]}"#.utf8
        )
        try unsupported.write(to: fileURL)

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).load()
        }
        #expect(try Data(contentsOf: fileURL) == unsupported)
    }
}

@Test func repositoryRejectsDuplicateAndEmptyTargetIdentifiers() throws {
    try withRepositoryFixture { _, fileURL in
        let duplicate = OpenTarget.builtIns[0]
        var duplicated = Settings()
        duplicated.targets = [duplicate, duplicate]
        var emptyID = Settings()
        emptyID.targets[0].id = "   "

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(duplicated)
        }
        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(emptyID)
        }
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}

/// Clearing every target is a legitimate choice — the user may want only the
/// copy-path action — so an empty list must save and must stay empty on reload.
@Test func repositoryAcceptsAndKeepsAnEmptyTargetList() throws {
    try withRepositoryFixture { _, fileURL in
        let repository = SettingsRepository(fileURL: fileURL)
        try repository.save(Settings(targets: []))

        #expect(try repository.load().targets.isEmpty)
    }
}

@Test func semanticallyInvalidPersistedSettingsAreNotOverwritten() throws {
    try withRepositoryFixture { _, fileURL in
        let invalid = Data(
            #"{"version":1,"targets":[{"id":"same","name":"Editor A","kind":"application","bundleIdentifier":"com.example.a","isEnabled":true},{"id":"same","name":"Editor B","kind":"application","bundleIdentifier":"com.example.b","isEnabled":true}],"copiesPaths":true,"directories":[]}"#.utf8
        )
        try invalid.write(to: fileURL)

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).load()
        }
        #expect(try Data(contentsOf: fileURL) == invalid)
    }
}

@Test func repositoryRejectsTargetsWithoutAUsableRoute() throws {
    try withRepositoryFixture { _, fileURL in
        let target = OpenTarget(
            id: "unroutable",
            name: "No Route",
            kind: .application,
            bundleIdentifier: nil,
            applicationURL: nil,
            isEnabled: true
        )
        let settings = Settings(targets: [target])

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(settings)
        }
    }
}

@Test func repositoryRejectsARegularApplicationMarkedAsTerminal() throws {
    try withRepositoryFixture { _, fileURL in
        let target = OpenTarget(
            id: "wrong-terminal",
            name: "Cursor",
            kind: .terminal,
            bundleIdentifier: "com.todesktop.230313mzl4w4u92",
            applicationURL: nil,
            isEnabled: true
        )

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(Settings(targets: [target]))
        }
    }
}

@Test(arguments: [
    "relative/folder",
    "https://example.com/folder",
    "file://server.example.com/Volumes/project",
])
func repositoryRejectsInvalidDirectoryURLs(_ rawURL: String) throws {
    try withRepositoryFixture { _, fileURL in
        let directory = try #require(URL(string: rawURL))
        let settings = Settings(directories: [directory])

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(settings)
        }
    }
}

@Test func repositoryRejectsNonApplicationTargetURL() throws {
    try withRepositoryFixture { root, fileURL in
        let executable = root.appendingPathComponent("tool")
        let target = OpenTarget(
            id: "tool",
            name: "Tool",
            kind: .application,
            bundleIdentifier: nil,
            applicationURL: executable,
            isEnabled: true
        )

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(Settings(targets: [target]))
        }
    }
}

@Test func repositoryRejectsApplicationPathsThatClimbWithParentComponents() throws {
    try withRepositoryFixture { root, fileURL in
        let target = OpenTarget(
            id: "editor",
            name: "Editor",
            kind: .application,
            bundleIdentifier: "test.editor",
            applicationURL: root.appendingPathComponent("Editor.app/../../tmp/Evil.app"),
            isEnabled: true
        )

        #expect(throws: (any Error).self) {
            try SettingsRepository(fileURL: fileURL).save(Settings(targets: [target]))
        }
    }
}

@Test func repositoryKeepsApplicationNamesThatMerelyContainDots() throws {
    try withRepositoryFixture { root, fileURL in
        let application = root.appendingPathComponent("版本..2.app", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)
        let target = OpenTarget(
            id: "editor",
            name: "版本..2",
            kind: .application,
            bundleIdentifier: "test.dots",
            applicationURL: application,
            isEnabled: true
        )
        let repository = SettingsRepository(fileURL: fileURL)

        try repository.save(Settings(targets: [target]))

        #expect(try repository.load().targets.first?.applicationURL?.path == application.path)
    }
}

@Test func repositoryErrorsHaveChineseDescriptions() throws {
    try withRepositoryFixture { _, fileURL in
        try Data("not-json".utf8).write(to: fileURL)

        do {
            _ = try SettingsRepository(fileURL: fileURL).load()
            Issue.record("损坏配置应该抛出错误")
        } catch let error as LocalizedError {
            let description = try #require(error.errorDescription)
            #expect(description.contains("配置"))
        } catch {
            Issue.record("错误必须实现 LocalizedError：\(error)")
        }
    }
}

private func withRepositoryFixture(_ body: (URL, URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("OneClickRepositoryTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root, root.appendingPathComponent("settings.json"))
}
