import Foundation
import Testing
@testable import OneClickCore

@Suite @MainActor
struct SettingsModelTests {
    @Test func firstLaunchPersistsHomeAndReloadPreservesEdits() throws {
        let harness = try SettingsHarness()
        let model = harness.model()
        #expect(model.configurationAvailable)
        #expect(try harness.files.settings.load().directories == [harness.files.root])
        model.setEnabled("terminal", false)
        model.save()
        let reloaded = harness.model()
        #expect(reloaded.settings.targets.first { $0.id == "terminal" }?.isEnabled == false)
        #expect(harness.notifications == 2)
    }

    @Test func bothReorderInteractionsPersistTheRequestedOrder() throws {
        let harness = try SettingsHarness()
        try harness.files.settings.save(Settings(targets: sampleTargets))
        let model = harness.model()
        model.move("test-terminal", by: -1)
        #expect(try harness.files.settings.load().targets.map(\.id) == ["test-vscode", "test-cursor", "test-terminal", "test-sublime", "test-nova"])
        model.move(from: IndexSet([0, 2]), to: 5)
        #expect(try harness.files.settings.load().targets.map(\.id) == ["test-cursor", "test-sublime", "test-nova", "test-vscode", "test-terminal"])
        model.move("test-cursor", by: -1)
        model.move("unknown", by: 1)
        #expect(harness.notifications == 2)
    }

    @Test func customApplicationsDeduplicateByBundleAndCanBeRemoved() throws {
        let harness = try SettingsHarness()
        let app = try harness.files.application("My Editor", identifier: "test.editor")
        let duplicate = try harness.files.application("Other Name", identifier: "test.editor")
        let invalid = try harness.files.directory("Invalid.app")
        let model = harness.model()
        model.addApplications([app, duplicate, invalid])
        let added = try #require(try harness.files.settings.load().targets.first { $0.bundleIdentifier == "test.editor" })
        #expect(added.name == "My Editor")
        #expect(added.applicationURL == app)
        #expect(model.settings.targets.count == 2)
        model.remove(added.id)
        #expect(try harness.files.settings.load().targets.map(\.id) == ["terminal"])
    }

    @Test func directoryChangesDeduplicateAndPersist() throws {
        let harness = try SettingsHarness()
        let directory = try harness.files.directory("中文 + project")
        let model = harness.model()
        model.addDirectories([directory, directory, harness.files.root])
        #expect(try harness.files.settings.load().directories == [harness.files.root, directory])
        model.removeDirectory(directory)
        #expect(try harness.files.settings.load().directories == [harness.files.root])
    }

    /// Removing every directory leaves the extension observing nothing, so the
    /// context menu disappears everywhere. Restoring the shipped default is the
    /// way back, and it has to persist like any other edit.
    @Test func restoringTheDefaultDirectoryBringsBackTheHomeDirectory() throws {
        let harness = try SettingsHarness()
        try harness.files.settings.save(Settings(directories: []))
        let model = harness.model()
        #expect(model.settings.directories.isEmpty)
        #expect(!model.isDefaultDirectoryConfigured)

        model.restoreDefaultDirectory()

        #expect(try harness.files.settings.load().directories == [harness.files.root])
        #expect(model.isDefaultDirectoryConfigured)
        #expect(harness.notifications == 1)
    }

    @Test func restoringTheDefaultDirectoryDoesNotDuplicateIt() throws {
        let harness = try SettingsHarness()
        let model = harness.model()
        #expect(model.isDefaultDirectoryConfigured)

        model.restoreDefaultDirectory()

        #expect(try harness.files.settings.load().directories == [harness.files.root])
    }

    @Test func refreshReflectsInstallationAndExtensionChanges() throws {
        let harness = try SettingsHarness()
        try harness.files.settings.save(Settings(targets: sampleTargets))
        let model = harness.model()
        #expect(model.availableCount == 2)
        model.setEnabled("test-terminal", false)
        #expect(model.availableCount == 1)
        harness.availableIDs = ["test-sublime"]
        harness.extensionEnabled = true
        model.refresh()
        #expect(model.availableCount == 1)
        #expect(model.availableApplications["test-vscode"] == nil)
        #expect(model.availableApplications["test-sublime"] != nil)
        #expect(model.extensionEnabled)
    }

    @Test func corruptConfigurationIsNotOverwritten() throws {
        let harness = try SettingsHarness()
        let url = harness.files.root.appendingPathComponent("settings.json")
        let invalid = Data("broken-json".utf8)
        try invalid.write(to: url)
        let model = harness.model()
        #expect(!model.configurationAvailable)
        #expect(model.errorMessage != nil)
        model.setEnabled("terminal", false)
        #expect(try Data(contentsOf: url) == invalid)
        #expect(harness.notifications == 0)
    }

    @Test func failedSaveReportsErrorWithoutNotifyingFinder() throws {
        let harness = try SettingsHarness()
        let model = harness.model()
        let url = harness.files.root.appendingPathComponent("settings.json")
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        model.setEnabled("terminal", false)
        #expect(model.errorMessage != nil)
        #expect(harness.notifications == 0)
    }
}
