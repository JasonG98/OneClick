import SwiftUI

@main
struct OneClickApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // The presenter is installed at app scope: the reopen path needs it, and
        // it always arrives after the scene is built.
        //
        // The window is opened on the next main-actor turn rather than inline:
        // this closure also runs while the scene graph is still being built, and
        // asking for a window from inside that pass is not reliable.
        let _ = delegate.installSettingsPresenter {
            Task { @MainActor in
                openWindow(id: "settings")
                NSApp.activate()
            }
        }
        Window("OneClick", id: "settings") {
            // The window keeps the system background instead of a window-wide
            // material: a translucent sheet behind every pane flattened the
            // sidebar, the list and the toolbar into one grey slab.
            SettingsView(model: delegate.model)
        }
        .defaultSize(width: 720, height: 440)
        .windowResizability(.contentMinSize)
        .restorationBehavior(.disabled)
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
