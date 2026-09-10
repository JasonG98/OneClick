import AppKit
import Darwin
import Foundation

/// Reads and writes the shared note that says the Finder extension is alive.
///
/// Both processes go through the app group container rather than `pluginkit`
/// queries: the container is already the shared channel for settings, it needs
/// no extra entitlement, and it stays readable while the extension is not.
enum ExtensionLiveness {
    /// The extension process cannot see the settings window's clock, and the
    /// settings window cannot see the extension's, so both sides agree on one
    /// value: the extension writes `Date()` and the app compares it with its own.
    @discardableResult
    static func recordHeartbeat(container: URL, bundleIdentifier: String, now: Date = Date()) -> Bool {
        let heartbeat = ExtensionHeartbeat(
            processIdentifier: ProcessInfo.processInfo.processIdentifier,
            bundleIdentifier: bundleIdentifier,
            recordedAt: now
        )
        guard let data = try? JSONEncoder().encode(heartbeat) else { return false }
        return (try? data.write(to: container.appendingPathComponent(ExtensionHeartbeat.fileName), options: .atomic)) != nil
    }

    static func heartbeat(container: URL) -> ExtensionHeartbeat? {
        let url = container.appendingPathComponent(ExtensionHeartbeat.fileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ExtensionHeartbeat.self, from: data)
    }

    static func clearHeartbeat(container: URL) {
        try? FileManager.default.removeItem(at: container.appendingPathComponent(ExtensionHeartbeat.fileName))
    }

    static func isRunning(_ heartbeat: ExtensionHeartbeat) -> Bool {
        NSRunningApplication(processIdentifier: heartbeat.processIdentifier)?
            .bundleIdentifier == heartbeat.bundleIdentifier
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
    static func reload(appex: URL, bundleIdentifier: String, container: URL, timeout: TimeInterval = 8) async -> Bool {
        await Task.detached { () -> Bool in
            _ = run(pluginkit, ["-a", appex.path])
            _ = run(pluginkit, ["-e", "use", "-i", bundleIdentifier])

            let deadline = Date().addingTimeInterval(timeout)
            while Date() < deadline {
                if let heartbeat = ExtensionLiveness.heartbeat(container: container),
                   ExtensionLiveness.isRunning(heartbeat),
                   heartbeat.recordedAt >= Date().addingTimeInterval(-timeout) {
                    return true
                }
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
