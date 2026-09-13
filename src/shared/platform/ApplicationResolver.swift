import Foundation

@MainActor
struct ApplicationResolver {
    /// Terminal is a built-in target and by convention carries no stored path
    /// (`SettingsRepository` requires `.terminal` to have a nil
    /// `applicationURL`), so the one system application this product depends on
    /// resolves from a fixed location. Looking it up by identifier would let
    /// any bundle claiming `com.apple.Terminal` take the open over.
    private static let systemTerminal = URL(
        fileURLWithPath: "/System/Applications/Utilities/Terminal.app",
        isDirectory: true
    )

    func applicationURL(for target: OpenTarget) -> URL? {
        // Only the path the user chose is honoured. Falling back to a lookup by
        // bundle identifier hands the choice to LaunchServices registration
        // order, where another bundle claiming the same identifier can take the
        // open over while the menu still shows the name the user picked.
        let stored = target.applicationURL ?? (target.kind == .terminal ? Self.systemTerminal : nil)
        guard let url = stored,
              FileManager.default.fileExists(atPath: url.path),
              Bundle(url: url)?.bundleIdentifier == target.bundleIdentifier else { return nil }
        return executableApplication(url)
    }

    private func executableApplication(_ url: URL) -> URL? {
        guard let executable = Bundle(url: url)?.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        return url
    }
}
