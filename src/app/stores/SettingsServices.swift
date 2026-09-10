import AppKit
import FinderSync

@MainActor
struct SettingsServices {
    var repository: () throws -> SettingsRepository
    var homeDirectory: URL
    var applicationURL: (OpenTarget) -> URL?
    /// The system toggle alone. Kept for callers that only ask "is it on".
    var extensionEnabled: () -> Bool
    /// The toggle plus whether an extension process is actually alive.
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
            extensionEnabled: { FIFinderSyncController.isExtensionEnabled },
            extensionAvailability: {
                let heartbeat = (try? SharedEnvironment.containerURL())
                    .flatMap { ExtensionLiveness.heartbeat(container: $0) }
                return ExtensionAvailabilityEvaluator(
                    isEnabled: FIFinderSyncController.isExtensionEnabled,
                    heartbeat: heartbeat,
                    isRunning: { ExtensionLiveness.isRunning($0) },
                    now: { Date() }
                ).evaluate()
            },
            reloadExtension: {
                guard let container = try? SharedEnvironment.containerURL() else { return false }
                let appex = Bundle.main.builtInPlugInsURL?
                    .appendingPathComponent("OneClickFinder.appex")
                guard let appex, FileManager.default.fileExists(atPath: appex.path) else { return false }
                return await FinderExtensionController.reload(
                    appex: appex,
                    bundleIdentifier: SharedEnvironment.extensionIdentifier,
                    container: container
                )
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
