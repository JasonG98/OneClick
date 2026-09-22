import AppKit
import Foundation

/// Asks the system whether the Finder extension is alive.
///
/// Liveness is not something the extension can report about itself. A note it
/// writes cannot outlive it: `deinit` never runs when the process is killed, and
/// every rebuild replaces the `.appex` underneath the running process. The
/// process registry already holds the answer, and it is the only copy of it that
/// stays true while the extension is gone.
enum ExtensionLiveness {
    /// The extension this build ships, where Xcode embeds it.
    static var embeddedExtensionURL: URL? {
        Bundle.main.builtInPlugInsURL?.appendingPathComponent("OneClickFinder.appex")
    }

    /// Whether the shipped extension is running right now.
    ///
    /// The identifier comes from the built appex rather than a repeated constant,
    /// so the answer is about *this* build's extension. A stale copy left
    /// registered by Xcode still reports as running, which is honest: it is
    /// serving Finder's menus either way.
    ///
    /// Only the app asks this, and only the app may: the query needs the
    /// process registry, which a sandboxed caller cannot see. The extension is
    /// sandboxed; its container app deliberately is not (`config/` — the
    /// extension carries an app-sandbox entitlement, the app has no sandbox
    /// or App Group entitlement). Sandboxing the app would turn every answer false.
    static func isRunning(extension appex: URL?) -> Bool {
        guard let appex, let identifier = Bundle(url: appex)?.bundleIdentifier else { return false }
        return !NSRunningApplication.runningApplications(withBundleIdentifier: identifier).isEmpty
    }
}

/// Brings the extension back after its process died.
///
/// Finder starts a Finder Sync extension once and does not start it again when
/// that process exits, so a rebuild that replaces the `.appex` leaves the
/// extension enabled in System Settings and absent from Finder until the plugin
/// is re-elected. Every step below was verified on macOS 26.6: `pluginkit -a`
/// registers the exact bundle that was just built, and `pluginkit -e use`
/// restarts it without disturbing the user's other extensions.
enum FinderExtensionController {
    static let pluginkit = "/usr/bin/pluginkit"

    /// Re-registers `appex` and re-elects it, then waits briefly for the
    /// extension to appear. Returns whether it is running afterwards.
    ///
    /// The work is off the main actor: `pluginkit` is a child process and the
    /// wait can last several seconds, and none of that belongs on the thread
    /// drawing the settings window.
    static func reload(appex: URL, timeout: TimeInterval = 8) async -> Bool {
        guard let identifier = Bundle(url: appex)?.bundleIdentifier else { return false }
        return await Task.detached { () -> Bool in
            _ = run(pluginkit, ["-a", appex.path])
            _ = run(pluginkit, ["-e", "use", "-i", identifier])

            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if ExtensionLiveness.isRunning(extension: appex) { return true }
                try? await Task.sleep(for: .milliseconds(250))
            }
            return false
        }.value
    }

    private static func run(_ executable: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}
