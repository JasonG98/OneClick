import Foundation
import Testing
@testable import OneClickCore

/// The system toggle and a live extension process are different facts, and the
/// gap between them is what made a working toggle look like a broken product:
/// after a rebuild the extension process is gone while System Settings still
/// says "on", and Finder never starts it again by itself.
@Suite struct ExtensionAvailabilityTests {
    private func evaluate(isEnabled: Bool, isRunning: Bool) -> ExtensionAvailability {
        ExtensionAvailabilityEvaluator(isEnabled: isEnabled, isRunning: { isRunning }).evaluate()
    }

    @Test func disabledToggleWinsOverEverythingElse() {
        #expect(evaluate(isEnabled: false, isRunning: true) == .disabled)
        #expect(evaluate(isEnabled: false, isRunning: false) == .disabled)
    }

    /// The exact state a rebuild produces: the system toggle is still on and the
    /// extension process behind it is gone.
    @Test func enabledExtensionWithNoRunningProcessIsNotRunning() {
        #expect(evaluate(isEnabled: true, isRunning: false) == .enabledNotRunning)
    }

    @Test func runningExtensionIsReportedAsEnabled() {
        #expect(evaluate(isEnabled: true, isRunning: true) == .enabled)
    }
}

@Suite @MainActor
struct ExtensionReloadTests {
    /// The card has to send the user somewhere useful in every state, so the
    /// three states must stay distinguishable from the model's point of view.
    @Test func modelReportsTheExtensionProcessNotTheToggleAlone() throws {
        let harness = try SettingsHarness()
        harness.extensionEnabled = true
        harness.extensionRunning = false
        let model = harness.model()
        #expect(model.extensionAvailability == .enabledNotRunning)

        harness.extensionRunning = true
        model.refresh()
        #expect(model.extensionAvailability == .enabled)
    }

    @Test func aSuccessfulReloadRefreshesTheStatusWithoutAnError() async throws {
        let harness = try SettingsHarness()
        harness.extensionEnabled = true
        let model = harness.model()
        #expect(model.extensionAvailability == .enabledNotRunning)

        model.reloadExtension()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(200))

        #expect(harness.reloadCount == 1)
        #expect(!model.reloadingExtension)
        #expect(model.errorMessage == nil)
    }

    /// When the extension refuses to come back, the user needs the manual
    /// System Settings route rather than a card that silently stays yellow.
    @Test func aFailedReloadExplainsTheManualRecovery() async throws {
        let harness = try SettingsHarness()
        harness.extensionEnabled = true
        harness.reloadSucceeds = false
        let model = harness.model()

        model.reloadExtension()
        await Task.yield()
        try await Task.sleep(for: .milliseconds(200))

        #expect(harness.reloadCount == 1)
        #expect(model.errorMessage?.contains("登录项与扩展") == true)
        #expect(model.extensionAvailability == .enabledNotRunning)
    }
}
