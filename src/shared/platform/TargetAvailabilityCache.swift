import AppKit

/// Caches resolved application URLs and icons for the life of the extension
/// process.
///
/// The extension is long-lived, so without this every menu build paid for cold
/// `NSWorkspace` icon lookups on the critical path of Finder's synchronous menu
/// callback — measured at 18.269 ms for the first lookup of a new process
/// against 0.644 ms once warm. The menu callback blocks Finder until it returns,
/// so that is user-visible latency on every right-click after Finder relaunches
/// the extension.
///
/// Only successful lookups are remembered. A target that is not installed has to
/// be re-checked, otherwise installing an application while the extension is
/// running would never show up.
@MainActor
final class TargetAvailabilityCache {
    private var applications: [String: URL] = [:]
    private var icons: [String: NSImage] = [:]
    private let resolve: (OpenTarget) -> URL?
    private let iconForFile: (URL) -> NSImage

    init(resolve: @escaping (OpenTarget) -> URL? = { ApplicationResolver().applicationURL(for: $0) },
         iconForFile: @escaping (URL) -> NSImage = { NSWorkspace.shared.icon(forFile: $0.path) }) {
        self.resolve = resolve
        self.iconForFile = iconForFile
    }

    func applicationURL(for target: OpenTarget) -> URL? {
        if let cached = applications[target.id] { return cached }
        guard let url = resolve(target) else { return nil }
        applications[target.id] = url
        return url
    }

    func icon(for target: OpenTarget) -> NSImage? {
        if let cached = icons[target.id] { return cached }
        guard let url = applicationURL(for: target) else { return nil }
        let image = iconForFile(url)
        icons[target.id] = image
        return image
    }

    /// The configuration changed: a target may have been imported, removed or
    /// moved, so resolved paths and their icons are no longer trustworthy.
    func invalidate() {
        applications.removeAll()
        icons.removeAll()
    }
}
