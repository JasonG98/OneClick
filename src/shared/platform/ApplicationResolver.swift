import AppKit

@MainActor
struct ApplicationResolver {
    func applicationURL(for target: OpenTarget) -> URL? {
        if let url = target.applicationURL,
           FileManager.default.fileExists(atPath: url.path),
           Bundle(url: url)?.bundleIdentifier == target.bundleIdentifier {
            return executableApplication(url)
        }
        guard let identifier = target.bundleIdentifier else { return nil }
        return executableApplication(NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier))
    }

    private func executableApplication(_ url: URL?) -> URL? {
        guard let url, let executable = Bundle(url: url)?.executableURL,
              FileManager.default.isExecutableFile(atPath: executable.path) else { return nil }
        return url
    }
}
