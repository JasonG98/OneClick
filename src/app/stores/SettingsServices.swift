import AppKit
import FinderSync

@MainActor
struct SettingsServices {
    var repository: () throws -> SettingsRepository
    var homeDirectory: URL
    var applicationURL: (OpenTarget) -> URL?
    /// The toggle plus whether an extension process is actually alive, because
    /// "enabled" and "running" are different facts.
    var extensionAvailability: () -> ExtensionAvailability
    /// Re-registers the built extension and re-elects it, without restarting
    /// Finder. Asynchronous because it spawns `pluginkit` and waits for the
    /// extension process to appear.
    var reloadExtension: () async -> Bool
    var settingsChanged: () -> Void
    var takeError: () -> String?
    var presentError: () -> Void

    static var live: SettingsServices {
        SettingsServices(
            repository: { try SharedEnvironment.repository() },
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            applicationURL: { ApplicationResolver().applicationURL(for: $0) },
            extensionAvailability: {
                ExtensionAvailabilityEvaluator(
                    isEnabled: FIFinderSyncController.isExtensionEnabled,
                    isRunning: { ExtensionLiveness.isRunning(extension: ExtensionLiveness.embeddedExtensionURL) }
                ).evaluate()
            },
            reloadExtension: {
                guard let appex = ExtensionLiveness.embeddedExtensionURL,
                      FileManager.default.fileExists(atPath: appex.path) else { return false }
                return await FinderExtensionController.reload(appex: appex)
            },
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
