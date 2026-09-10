import AppKit
import Testing
@testable import OneClickCore

@MainActor
struct AppLifecycleTests {
    @Test func ordinaryLaunchExplicitlyRequestsSettings() {
        let delegate = AppDelegate()
        var presentations = 0
        delegate.showSettings = { presentations += 1 }
        #expect(!delegate.applicationShouldOpenUntitledFile(NSApplication.shared))
        #expect(presentations == 1)
    }

    @Test func reopeningRequestsSettingsEvenAfterTheWindowWasClosed() {
        let delegate = AppDelegate()
        var presentations = 0
        delegate.showSettings = { presentations += 1 }
        #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        #expect(presentations == 1)
        #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
        #expect(presentations == 2)
    }

    @Test func unrelatedURLDoesNotRequestSettings() {
        let delegate = AppDelegate()
        var presentations = 0
        delegate.showSettings = { presentations += 1 }
        delegate.application(NSApplication.shared, open: [URL(string: "oneclick://invalid")!])
        #expect(presentations == 0)
    }

    @Test func closingSettingsDoesNotTerminateBackgroundProcessing() {
        #expect(!AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }
}
