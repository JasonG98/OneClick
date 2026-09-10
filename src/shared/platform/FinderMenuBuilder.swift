import AppKit

@MainActor
struct FinderMenuBuilder {
    var available: (OpenTarget) -> Bool = { ApplicationResolver().applicationURL(for: $0) != nil }
    var icon: (OpenTarget) -> NSImage? = { ApplicationResolver().icon(for: $0) }

    func makeMenu(settings: Settings, selection: SelectionContext, actions: inout MenuActionRegistry,
                  handler: AnyObject? = nil, openAction: Selector? = nil, copyAction: Selector? = nil) -> NSMenu? {
        guard !selection.urls.isEmpty else { return nil }
        let menu = NSMenu()
        let targets = settings.targets.filter { $0.isEnabled && available($0) }
        if !targets.isEmpty {
            let open = NSMenuItem(title: "在应用中打开", action: nil, keyEquivalent: "")
            open.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: nil)
            let submenu = NSMenu()
            for target in targets {
                let item = NSMenuItem(title: target.name, action: openAction, keyEquivalent: "")
                item.target = handler
                item.tag = actions.insert(selection: selection, target: target)
                let image = icon(target)?.copy() as? NSImage
                image?.size = NSSize(width: 16, height: 16)
                item.image = image
                submenu.addItem(item)
            }
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
