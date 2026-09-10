import Foundation
import Testing
@testable import OneClickCore

/// The system toggle and a live extension process are different facts, and the
/// gap between them is what made a working toggle look like a broken product:
/// after a rebuild the extension process is gone while System Settings still
/// says "on", and Finder never starts it again by itself.
@Suite struct ExtensionAvailabilityTests {
    private func heartbeat(ago: TimeInterval, pid: Int32 = 4242) -> ExtensionHeartbeat {
        ExtensionHeartbeat(
            processIdentifier: pid,
            bundleIdentifier: "local.oneclick.app.finder",
            recordedAt: Date().addingTimeInterval(-ago)
        )
    }

    private func evaluate(isEnabled: Bool, heartbeat: ExtensionHeartbeat?, isRunning: Bool) -> ExtensionAvailability {
        ExtensionAvailabilityEvaluator(
            isEnabled: isEnabled,
            heartbeat: heartbeat,
            isRunning: { _ in isRunning },
            now: { Date() }
        ).evaluate()
    }

    @Test func disabledToggleWinsOverEverythingElse() {
        #expect(evaluate(isEnabled: false, heartbeat: heartbeat(ago: 0), isRunning: true) == .disabled)
        #expect(evaluate(isEnabled: false, heartbeat: nil, isRunning: false) == .disabled)
    }

    @Test func enabledExtensionWithNoHeartbeatIsNotRunning() {
        #expect(evaluate(isEnabled: true, heartbeat: nil, isRunning: false) == .enabledNotRunning)
    }

    /// The exact state a rebuild produces: the system toggle is still on, the
    /// last heartbeat names a process that no longer exists.
    @Test func enabledExtensionWhoseProcessDiedIsNotRunning() {
        #expect(evaluate(isEnabled: true, heartbeat: heartbeat(ago: 1), isRunning: false) == .enabledNotRunning)
    }

    @Test func liveExtensionWithAFreshHeartbeatIsReportedAsEnabled() {
        #expect(evaluate(isEnabled: true, heartbeat: heartbeat(ago: 1), isRunning: true) == .enabled)
    }

    /// Finder asks for menus only when the user interacts, so a healthy but idle
    /// extension can go a long time between heartbeats. Anything inside the grace
    /// window is still the live extension, not a dead one.
    @Test func anIdleButAliveExtensionStaysEnabled() {
        let withinGrace = ExtensionAvailabilityEvaluator.notRunningGrace - 60
        #expect(evaluate(isEnabled: true, heartbeat: heartbeat(ago: withinGrace), isRunning: true) == .enabled)
    }

    /// A heartbeat old enough to predate this session cannot vouch for the
    /// process that is running now.
    @Test func aStaleHeartbeatBeyondTheGraceWindowIsNotRunning() {
        let stale = heartbeat(ago: ExtensionAvailabilityEvaluator.notRunningGrace + 60)
        #expect(evaluate(isEnabled: true, heartbeat: stale, isRunning: true) == .enabledNotRunning)
    }
}

@Suite @MainActor
struct ExtensionReloadTests {
    /// The card has to send the user somewhere useful in every state, so the
    /// three states must stay distinguishable from the model's point of view.
    @Test func modelReportsTheExtensionProcessNotTheToggleAlone() throws {
        let harness = try SettingsHarness()
        harness.extensionEnabled = true
        harness.extensionHeartbeat = ExtensionHeartbeat(
            processIdentifier: 4242,
            bundleIdentifier: "local.oneclick.app.finder",
            recordedAt: Date()
        )
        harness.extensionRunning = false
        let model = harness.model()
        #expect(model.extensionEnabled)
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
