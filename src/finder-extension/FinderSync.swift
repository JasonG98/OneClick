import AppKit
import FinderSync
import OSLog

/// One extension process, one cache. It cannot be an instance property: its
/// default value is main-actor isolated, and `FIFinderSync.init` is not.
@MainActor private let availabilityCache = TargetAvailabilityCache()

final class FinderSync: FIFinderSync, @unchecked Sendable {
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "finder")
    @MainActor private var actions = MenuActionRegistry()

    override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(settingsDidChange), name: SharedEnvironment.settingsChanged, object: nil)
        refreshDirectories()
        logger.info("Finder extension initialized")
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }

    /// The toolbar button is the app's only persistent entry point.
    ///
    /// The container app is no longer launched in the background, so there is no
    /// menu bar item to reach settings from. This button lives in the extension
    /// that is already resident and costs no extra process. Finder reads these by
    /// calling the getters, so they are overridden rather than assigned.
    override var toolbarItemName: String { "OneClick" }

    override var toolbarItemToolTip: String { "OneClick：用指定应用打开，或复制路径" }

    override var toolbarItemImage: NSImage { Self.toolbarImage }

    private static let toolbarImage: NSImage = {
        let image = NSImage(systemSymbolName: "cursorarrow.click.2", accessibilityDescription: "OneClick")
            ?? NSImage(size: NSSize(width: 18, height: 18))
        image.isTemplate = true
        return image
    }()

    @objc private func settingsDidChange() {
        let settings = refreshDirectories()
        Task { @MainActor in self.invalidateAvailabilityIfResolutionChanged(settings) }
    }

    @MainActor private var lastResolutionFingerprint: String?

    /// Enabling or disabling a target, or editing directories, cannot change how
    /// an application resolves, so the cache only pays a full re-resolution when
    /// a resolution input actually moved.
    @MainActor
    private func invalidateAvailabilityIfResolutionChanged(_ settings: Settings?) {
        guard let settings else {
            availabilityCache.invalidate()
            return
        }
        let fingerprint = settings.targets.map { target in
            "\(target.id)|\(target.bundleIdentifier ?? "")|\(target.applicationURL?.path ?? "")"
        }.joined(separator: ",")
        guard fingerprint != lastResolutionFingerprint else { return }
        lastResolutionFingerprint = fingerprint
        availabilityCache.invalidate()
    }

    /// Returns the configuration it loaded: the refresh triggered by a settings
    /// change also needs it to decide whether resolution inputs moved, and that
    /// must not cost a second read of the same file.
    @discardableResult
    private func refreshDirectories() -> Settings? {
        do {
            let settings = try SharedEnvironment.repository().load()
            let roots = Set(settings.directories)
            // Re-assigning the same roots makes Finder re-register every time a
            // refresh is triggered; only touch it when the set really changed.
            if FIFinderSyncController.default().directoryURLs != roots {
                FIFinderSyncController.default().directoryURLs = roots
                logger.info("Observing \(roots.count) configured roots")
            }
            return settings
        } catch {
            FIFinderSyncController.default().directoryURLs = []
            SharedEnvironment.report(error)
            logger.error("Configuration unavailable: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        logger.info("Menu requested, kind \(menuKind.rawValue)")
        // Finder supplies selection only during this synchronous XPC callback.
        // Capture it here, then construct AppKit objects on the main queue.
        let controller = FIFinderSyncController.default()
        let selection = SelectionContext(selected: controller.selectedItemURLs() ?? [], targeted: controller.targetedURL(), isContainer: menuKind == .contextualMenuForContainer)
        // Settings stay reachable from the toolbar even with nothing selected.
        let includeSettings = menuKind == .toolbarItemMenu
        return MainThreadBridge.sync { SynchronousMenu(value: self.makeMenu(selection: selection, includeSettings: includeSettings)) }.value
    }

    override func beginObservingDirectory(at url: URL) {
        logger.info("Finder began observing a configured directory")
    }

    @MainActor private func makeMenu(selection: SelectionContext, includeSettings: Bool) -> NSMenu? {
        let builder = FinderMenuBuilder(
            available: { availabilityCache.applicationURL(for: $0) != nil },
            icon: { availabilityCache.icon(for: $0) }
        )
        var menu: NSMenu?
        if !selection.urls.isEmpty {
            do {
                let settings = try SharedEnvironment.repository().load()
                menu = builder.makeMenu(settings: settings, selection: selection, actions: &actions,
                                        handler: self, openAction: #selector(openTarget(_:)), copyAction: #selector(copyPaths(_:)))
                logger.info("Built menu for \(selection.urls.count) items")
            } catch {
                ActionExecutor().presentFailure(error)
            }
        }
        if includeSettings {
            builder.addingSettingsItem(to: &menu, handler: self, action: #selector(openSettings(_:)))
        }
        return menu
    }

    @objc private func copyPaths(_ sender: NSMenuItem) {
        let tag = sender.tag
        Task { @MainActor in
            guard let action = actions.action(for: tag) else { return }
            do { try ActionExecutor().copyPaths(action.selection) }
            catch { ActionExecutor().presentFailure(error) }
        }
    }

    /// Every target is opened from inside the extension.
    ///
    /// This used to be handed to the container app because a sandboxed Finder
    /// extension cannot pass selected files to LaunchServices: the URLs from
    /// `selectedItemURLs()` carry no sandbox read access, so opening them with
    /// any application failed. The extension now holds a read-only exception
    /// entitlement, which is what makes the direct path work.
    @objc private func openTarget(_ sender: NSMenuItem) {
        let tag = sender.tag
        Task { @MainActor in
            guard let action = actions.action(for: tag), let target = action.target else { return }
            do { try await ActionExecutor().open(target, selection: action.selection) }
            catch { ActionExecutor().presentFailure(error) }
        }
    }

    @objc private func openSettings(_ sender: NSMenuItem) {
        guard let application = NSWorkspace.shared.urlForApplication(withBundleIdentifier: SharedEnvironment.appIdentifier) else {
            logger.error("Container application not found for settings")
            return
        }
        Task { @MainActor in
            do { try await SystemWorkspace().openApplication(application) }
            catch { ActionExecutor().presentFailure(error) }
        }
    }
}

// Finder serializes the menu when the synchronous callback returns. Only this
// short-lived return value crosses back to Finder's XPC queue; UI work stays on main.
private struct SynchronousMenu: @unchecked Sendable {
    let value: NSMenu?
}
