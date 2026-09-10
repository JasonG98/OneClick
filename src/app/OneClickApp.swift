import SwiftUI

@main
struct OneClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Install the action at app scope: a suppressed scene has no view
        // lifecycle on which to observe a settings-presentation request.
        let _ = delegate.showSettings = {
            openWindow(id: "settings")
            NSApp.activate()
        }
        Window("OneClick", id: "settings") {
            SettingsView(model: delegate.model)
                .handlesExternalEvents(preferring: [], allowing: [])
        }
        .defaultSize(width: 650, height: 760)
        .windowResizability(.contentMinSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        // Finder URLs are consumed by AppDelegate, never by the settings scene.
        .handlesExternalEvents(matching: [])
        .commands {
            CommandGroup(replacing: .newItem) {}
            SettingsCommands()
        }
    }
}

private struct SettingsCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("设置…") {
                openWindow(id: "settings")
                NSApp.activate()
            }
            .keyboardShortcut(",")
        }
    }
}
