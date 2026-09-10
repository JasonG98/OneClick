import AppKit
import FinderSync
import OSLog

final class FinderSync: FIFinderSync, @unchecked Sendable {
    private let logger = Logger(subsystem: SharedEnvironment.appIdentifier, category: "finder")
    @MainActor private var actions = MenuActionRegistry()

    override init() {
        super.init()
        DistributedNotificationCenter.default().addObserver(self, selector: #selector(settingsDidChange), name: SharedEnvironment.settingsChanged, object: nil)
        refreshDirectories()
        logger.info("Finder extension initialized")
    }

    deinit { DistributedNotificationCenter.default().removeObserver(self) }

    @objc private func settingsDidChange() { refreshDirectories() }

    private func refreshDirectories() {
        do {
            let settings = try SharedEnvironment.repository().load()
            FIFinderSyncController.default().directoryURLs = Set(settings.directories)
            logger.info("Observing \(settings.directories.count) configured roots")
        } catch {
            FIFinderSyncController.default().directoryURLs = []
            SharedEnvironment.report(error)
            logger.error("Configuration unavailable: \(error.localizedDescription, privacy: .public)")
        }
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        logger.info("Menu requested, kind \(menuKind.rawValue)")
        // Finder supplies selection only during this synchronous XPC callback.
        // Capture it here, then construct AppKit objects on the main queue.
        let controller = FIFinderSyncController.default()
        let selection = SelectionContext(selected: controller.selectedItemURLs() ?? [], targeted: controller.targetedURL(), isContainer: menuKind == .contextualMenuForContainer)
        return MainThreadBridge.sync { SynchronousMenu(value: self.makeMenu(selection: selection)) }.value
    }

    override func beginObservingDirectory(at url: URL) {
        logger.info("Finder began observing a configured directory")
    }

    @MainActor private func makeMenu(selection: SelectionContext) -> NSMenu? {
        guard !selection.urls.isEmpty else { return nil }
        do {
            let settings = try SharedEnvironment.repository().load()
            let menu = NSMenu()
            let resolver = ApplicationResolver()
            let targets = settings.targets.filter { $0.isEnabled && resolver.applicationURL(for: $0) != nil }
            if !targets.isEmpty {
                let open = NSMenuItem(title: "在应用中打开", action: nil, keyEquivalent: "")
                open.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
                let submenu = NSMenu()
                for target in targets {
                    let item = NSMenuItem(title: target.name, action: #selector(openTarget(_:)), keyEquivalent: "")
                    item.target = self
                    item.tag = actions.insert(selection: selection, target: target)
                    let icon = resolver.icon(for: target)?.copy() as? NSImage
                    icon?.size = NSSize(width: 16, height: 16)
                    item.image = icon
                    submenu.addItem(item)
                }
                open.submenu = submenu
                menu.addItem(open)
            }
            if settings.copiesPaths {
                let copy = NSMenuItem(title: selection.urls.count > 1 ? "复制 \(selection.urls.count) 个绝对路径" : "复制绝对路径", action: #selector(copyPaths(_:)), keyEquivalent: "")
                copy.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
                copy.target = self
                copy.tag = actions.insert(selection: selection, target: nil)
                menu.addItem(copy)
            }
            logger.info("Built menu for \(selection.urls.count) items")
            return menu.items.isEmpty ? nil : menu
        } catch {
            ActionExecutor().presentFailure(error)
            return nil
        }
    }
    @objc private func copyPaths(_ sender: NSMenuItem) {
        let tag = sender.tag
        Task { @MainActor in
            guard let action = actions.action(for: tag) else { return }
            do { try ActionExecutor().copyPaths(action.selection) }
            catch { ActionExecutor().presentFailure(error) }
        }
    }

    @objc private func openTarget(_ sender: NSMenuItem) {
        let tag = sender.tag
        Task { @MainActor in
            guard let action = actions.action(for: tag), let target = action.target else { return }
            do { try await OpenRequestDispatcher().open(target, selection: action.selection) }
            catch { ActionExecutor().presentFailure(error) }
        }
    }
}

// Finder serializes the menu when the synchronous callback returns. Only this
// short-lived return value crosses back to its XPC queue; UI work stays on main.
private struct SynchronousMenu: @unchecked Sendable {
    let value: NSMenu?
}
