import AppKit
import Testing
@testable import OneClickCore

@MainActor
struct AppLifecycleTests {
    /// The window presents itself on launch; the presenter only serves the
    /// reopen path, which always arrives after the scene installed it.
    @Test func reopeningRequestsSettingsEvenAfterTheWindowWasClosed() {
        let delegate = AppDelegate()
        var presentations = 0
        delegate.installSettingsPresenter { presentations += 1 }

        #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false))
        #expect(presentations == 1)
        #expect(!delegate.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true))
        #expect(presentations == 2)
    }

    /// The window is the app's entire surface -- the Finder extension does the
    /// work -- so dismissing it must not leave a process and a Dock icon behind.
    @Test func closingSettingsQuitsInsteadOfLingering() {
        #expect(AppDelegate().applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    }
}
