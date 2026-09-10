import AppKit

@MainActor
struct FinderMenuBuilder {
    var available: (OpenTarget) -> Bool = { ApplicationResolver().applicationURL(for: $0) != nil }
    var icon: (OpenTarget) -> NSImage? = { ApplicationResolver().icon(for: $0) }

    func makeMenu(settings: Settings, selection: SelectionContext, actions: inout MenuActionRegistry,
                  handler: AnyObject? = nil, openAction: Selector? = nil, copyAction: Selector? = nil) -> NSMenu? {
        guard !selection.urls.isEmpty else { return nil }
        let menu = NSMenu()
        let onlyDirectories = selection.urls.allSatisfy { url in
            guard url.isLocalFileURL else { return false }
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory)
                && isDirectory.boolValue
        }
        let targets = onlyDirectories ? settings.targets.filter { $0.isEnabled && available($0) } : []
        let submenu = NSMenu()
        for (index, target) in targets.enumerated() {
            let title = index < 3 ? "在 \(target.name) 中打开" : target.name
            let item = NSMenuItem(title: title, action: openAction, keyEquivalent: "")
            item.target = handler
            item.tag = actions.insert(selection: selection, target: target)
            let image = icon(target)?.copy() as? NSImage
            image?.size = NSSize(width: 16, height: 16)
            item.image = image
            if index < 3 {
                menu.addItem(item)
            } else {
                submenu.addItem(item)
            }
        }
        if !submenu.items.isEmpty {
            let open = NSMenuItem(title: "在应用中打开", action: nil, keyEquivalent: "")
            open.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
            open.submenu = submenu
            menu.addItem(open)
        }
        if settings.copiesPaths {
            let copy = NSMenuItem(title: selection.urls.count > 1 ? "复制 \(selection.urls.count) 个绝对路径" : "复制绝对路径", action: copyAction, keyEquivalent: "")
            copy.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil)
            copy.target = handler
            copy.tag = actions.insert(selection: selection, target: nil)
            menu.addItem(copy)
        }
        return menu.items.isEmpty ? nil : menu
    }
}
