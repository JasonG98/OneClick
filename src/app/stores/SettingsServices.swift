import AppKit
import FinderSync

@MainActor
struct SettingsServices {
    var repository: () throws -> SettingsRepository
    var homeDirectory: URL
    var applicationURL: (OpenTarget) -> URL?
    var extensionEnabled: () -> Bool
    var settingsChanged: () -> Void
    var takeError: () -> String?
    var presentError: () -> Void

    static var live: SettingsServices {
        SettingsServices(
            repository: { try SharedEnvironment.repository() },
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            applicationURL: { ApplicationResolver().applicationURL(for: $0) },
            extensionEnabled: { FIFinderSyncController.isExtensionEnabled },
            settingsChanged: {
                DistributedNotificationCenter.default().postNotificationName(SharedEnvironment.settingsChanged, object: nil, userInfo: nil, deliverImmediately: true)
            },
            takeError: { SharedEnvironment.takeError() },
            presentError: {
                NSApp.activate()
                NSApp.windows.first(where: { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
            }
        )
    }
}
