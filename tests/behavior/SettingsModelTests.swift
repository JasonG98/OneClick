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
        model.setEnabled("vscode", false)
        model.settings.copiesPaths = false
        model.save()
        let reloaded = harness.model()
        #expect(reloaded.settings.targets.first { $0.id == "vscode" }?.isEnabled == false)
        #expect(!reloaded.settings.copiesPaths)
        #expect(harness.notifications == 2)
    }

    @Test func bothReorderInteractionsPersistTheRequestedOrder() throws {
        let harness = try SettingsHarness()
        let model = harness.model()
        model.move("terminal", by: -1)
        #expect(try harness.files.settings.load().targets.map(\.id) == ["vscode", "cursor", "terminal", "sublime", "claude"])
        model.move(from: IndexSet([0, 2]), to: 5)
        #expect(try harness.files.settings.load().targets.map(\.id) == ["cursor", "sublime", "claude", "vscode", "terminal"])
        model.move("cursor", by: -1)
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
        #expect(model.settings.targets.count == 6)
        model.remove(added.id)
        #expect(try harness.files.settings.load().targets.map(\.id) == ["vscode", "cursor", "sublime", "terminal", "claude"])
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

    @Test func refreshReflectsInstallationAndExtensionChanges() throws {
        let harness = try SettingsHarness()
        let model = harness.model()
        #expect(model.availableCount == 2)
        model.setEnabled("terminal", false)
        #expect(model.availableCount == 1)
        harness.availableIDs = ["sublime"]
        harness.extensionEnabled = true
        model.refresh()
        #expect(model.availableCount == 1)
        #expect(model.availableApplications["vscode"] == nil)
        #expect(model.availableApplications["sublime"] != nil)
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
        model.setEnabled("vscode", false)
        #expect(try Data(contentsOf: url) == invalid)
        #expect(harness.notifications == 0)
    }

    @Test func failedSaveReportsErrorWithoutNotifyingFinder() throws {
        let harness = try SettingsHarness()
        let model = harness.model()
        let url = harness.files.root.appendingPathComponent("settings.json")
        try FileManager.default.removeItem(at: url)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        model.setEnabled("vscode", false)
        #expect(model.errorMessage != nil)
        #expect(harness.notifications == 0)
    }
}
