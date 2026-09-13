import AppKit

@MainActor
struct FinderMenuBuilder {
    /// Both are injected, never defaulted: the extension passes its long-lived
    /// `TargetAvailabilityCache`, tests pass fixtures. A default would resolve
    /// applications from scratch on every menu build, which is exactly the cold
    /// path that cache exists to keep off Finder's blocking callback.
    let available: (OpenTarget) -> Bool
    let icon: (OpenTarget) -> NSImage?

    /// Every menu image shares one box: app icons and symbols otherwise arrive
    /// at different heights (16x16 against 16x18) and the icon column jitters.
    private static let imageSize = NSSize(width: 16, height: 16)

    /// App icons are shared, cached images, so they are copied before being
    /// resized and are explicitly *not* templates: the menu must draw them as
    /// artwork, not tint them.
    private static func applicationImage(_ image: NSImage?) -> NSImage? {
        guard let image, let copy = image.copy() as? NSImage else { return image }
        copy.size = imageSize
        copy.isTemplate = false
        return copy
    }

    /// Symbols are drawn in an explicit colour instead of relying on template
    /// tinting.
    ///
    /// A template image is supposed to be recoloured by whoever draws the menu,
    /// and that is exactly what did not happen: the item images reach Finder as
    /// fixed artwork, so a symbol created while the system was dark stayed white
    /// on a light menu and disappeared. The colour is resolved here instead, at
    /// menu-build time. The menu is rebuilt on every invocation, so the icons
    /// always match the appearance in force when the menu was opened.
    /// Cached by name and resolved colour. Building a symbol costs more than
    /// building the rest of the menu put together, and these are three fixed
    /// decorations rebuilt on every invocation. Keying on the colour keeps the
    /// bake-at-build-time rule: switching appearance resolves a different image
    /// instead of reusing a stale one.
    private static var symbolImages: [String: NSImage] = [:]

    private static func symbol(_ name: String) -> NSImage? {
        let foreground = menuForegroundColor
        let key = "\(name)|\(foreground == .white)"
        if let cached = symbolImages[key] { return cached }
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
            .applying(NSImage.SymbolConfiguration(paletteColors: [foreground]))
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) else { return nil }
        image.size = imageSize
        // The colour is already baked in; a template flag would let the renderer
        // tint it again and undo the work.
        image.isTemplate = false
        symbolImages[key] = image
        return image
    }

    /// Reads the system setting rather than this process's appearance.
    ///
    /// A stale process appearance is precisely the failure this works around: an
    /// extension can keep reporting the appearance it started under long after
    /// the user switched modes.
    private static var menuForegroundColor: NSColor {
        UserDefaults.standard.string(forKey: "AppleInterfaceStyle") == "Dark" ? .white : .black
    }

    /// How many applications sit in the top level before the rest fold into a
    /// submenu. The submenu header carries the verb, so its entries are plain
    /// application names — the same wording `NSMenu` uses for "打开方式".
    ///
    /// Both positions print `OpenTarget.menuName`, never `name`: a long name
    /// ("用 Visual Studio Code 打开") spends the whole row on a name every user
    /// abbreviates anyway. Aliases live in `ApplicationAlias`, one entry per app.
    private static let inlineTargetLimit = 3

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
            let inline = index < Self.inlineTargetLimit
            let title = inline ? "用 \(target.menuName) 打开" : target.menuName
            let item = NSMenuItem(title: title, action: openAction, keyEquivalent: "")
            item.target = handler
            item.tag = actions.insert(selection: selection, target: target)
            item.image = Self.applicationImage(icon(target))
            if inline {
                menu.addItem(item)
            } else {
                submenu.addItem(item)
            }
        }
        if !submenu.items.isEmpty {
            let open = NSMenuItem(title: "用其他应用打开", action: nil, keyEquivalent: "")
            open.image = Self.symbol("arrow.up.forward.app")
            open.submenu = submenu
            menu.addItem(open)
        }
        // 菜单文案只写"复制路径"：动作结果不变（仍然是绝对路径），但标题不该
        // 把实现细节塞给用户 —— 长度和"绝对"两个字都是负担。语义写在 README 里。
        let copy = NSMenuItem(title: selection.urls.count > 1 ? "复制 \(selection.urls.count) 个路径" : "复制路径", action: copyAction, keyEquivalent: "")
        copy.image = Self.symbol("doc.on.doc")
        copy.target = handler
        copy.tag = actions.insert(selection: selection, target: nil)
        menu.addItem(copy)
        return menu.items.isEmpty ? nil : menu
    }

    /// Appends the always-available settings entry.
    ///
    /// The Finder toolbar button is the app's only persistent entry point, so it
    /// has to offer settings even when nothing is selected and there is no
    /// selection-dependent menu to attach to.
    ///
    /// No separator, and that is deliberate. `NSMenuItem.separator()` reserves its
    /// space in the menu Finder draws but the line itself never renders — measured
    /// on a real screenshot: the band is 35 rows of flat `rgb(85,81,76)` — so all
    /// it produced was a blank gap that read as a missing item. The row is set
    /// apart by carrying the app's own mark, the same glyph as the toolbar button
    /// the menu was opened from, instead of a generic gear.
    func addingSettingsItem(to menu: inout NSMenu?, handler: AnyObject?, action: Selector?) {
        let result = menu ?? NSMenu()
        let settings = NSMenuItem(title: "OneClick 设置…", action: action, keyEquivalent: "")
        settings.target = handler
        settings.image = Self.symbol("cursorarrow.click.2")
        result.addItem(settings)
        menu = result
    }
}
