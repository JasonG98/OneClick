import AppKit
import Testing
@testable import OneClickCore

@Suite @MainActor
struct FinderMenuTests {
    @Test(arguments: [3, 4, 5])
    func firstThreeApplicationsAreDirectAndOnlyRemainingApplicationsAreCollapsed(count: Int) throws {
        let targets = Array(sampleTargets.prefix(count))
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in nil })
        let files = try TemporaryFiles()
        let chosen = selection([try files.directory("folder")])
        let menu = try #require(builder.makeMenu(settings: Settings(targets: targets), selection: chosen, actions: &registry))
        #expect(menu.items.last?.title == "复制路径")
        let openMenuItems = Array(menu.items.dropLast())
        let direct = Array(openMenuItems.prefix(3))
        // 字面量而不是 targets.map(\.menuName)：这条断言的意义就是钉住菜单文案，
        // 用被测代码算期望值等于什么都没测。样例里同时有别名命中（VS Code）
        // 与未命中（Cursor）两种目标。
        #expect(direct.map(\.title) == ["用 VS Code 打开", "用 Cursor 打开", "用 Sublime 打开"])
        #expect(direct.allSatisfy { $0.submenu == nil })
        var openItems = direct
        if count > 3 {
            #expect(openMenuItems.count == 4)
            #expect(openMenuItems[3].title == "用其他应用打开")
            let submenu = try #require(openMenuItems[3].submenu)
            #expect(submenu.items.map(\.title) == (count == 4 ? ["Terminal"] : ["Terminal", "Nova"]))
            openItems += submenu.items
        } else {
            #expect(openMenuItems.count == 3)
        }
        #expect(openItems.compactMap { registry.action(for: $0.tag)?.target?.id } == targets.map(\.id))
        #expect(openItems.allSatisfy { registry.action(for: $0.tag)?.selection.urls == chosen.urls })
    }

    /// 别名在内联项和折叠子菜单里都要生效。
    ///
    /// 排到第 4 位之后的应用一样占菜单宽度，只改内联项等于只做了一半。
    /// 同时钉住一件容易做错的事：文案换了，点中的还得是原来那个目标。
    @Test func aliasesApplyToFoldedItemsToo() throws {
        let targets = [
            OpenTarget(id: "cursor", name: "Cursor", kind: .application, bundleIdentifier: "com.todesktop.230313mzl4w4u92", applicationURL: nil, isEnabled: true),
            OpenTarget(id: "nova", name: "Nova", kind: .application, bundleIdentifier: "com.panic.Nova", applicationURL: nil, isEnabled: true),
            OpenTarget(id: "terminal", name: "Terminal", kind: .terminal, bundleIdentifier: "com.apple.Terminal", applicationURL: nil, isEnabled: true),
            // 真实的长名字应用，别名表里应有它。
            OpenTarget(id: "editor", name: "Visual Studio Code", kind: .application, bundleIdentifier: "com.microsoft.VSCode", applicationURL: nil, isEnabled: true),
        ]
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in nil })
        let files = try TemporaryFiles()
        let menu = try #require(builder.makeMenu(settings: Settings(targets: targets), selection: selection([try files.directory("folder")]), actions: &registry))
        let openItems = Array(menu.items.dropLast())

        #expect(openItems.prefix(3).map(\.title) == ["用 Cursor 打开", "用 Nova 打开", "用 Terminal 打开"])
        let folded = try #require(openItems.last?.submenu)
        #expect(folded.items.map(\.title) == ["VS Code"])
        #expect(registry.action(for: folded.items[0].tag)?.target?.name == "Visual Studio Code")
    }

    @Test func menuFiltersTargetsPreservesOrderAndSnapshotsSelection() throws {
        var settings = Settings(targets: sampleTargets)
        settings.targets.reverse()
        settings.targets[0].isEnabled = false // Nova is installed but disabled.
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { ["test-terminal", "test-vscode"].contains($0.id) }, icon: { _ in nil })
        let files = try TemporaryFiles()
        let chosen = selection([try files.directory("中文 + ' a"), try files.directory("b")])
        let menu = try #require(builder.makeMenu(settings: settings, selection: chosen, actions: &registry))
        let openItems = Array(menu.items.dropLast())
        #expect(openItems.map(\.title) == ["用 Terminal 打开", "用 VS Code 打开"])
        #expect(openItems.allSatisfy { $0.submenu == nil && $0.tag > 0 })
        #expect(Set(openItems.map(\.tag)).count == 2)
        let action = try #require(registry.action(for: openItems[0].tag))
        #expect(action.target?.id == "test-terminal")
        #expect(action.selection.urls.map(\.path) == chosen.urls.map(\.path))
        let copy = try #require(menu.items.last)
        #expect(copy.title.contains("2"))
        #expect(registry.action(for: copy.tag)?.target == nil)
        #expect(registry.action(for: copy.tag)?.selection.pathText == chosen.pathText)
    }

    @Test(arguments: [false, true])
    func filesAndMixedSelectionsHideAllApplicationItems(mixed: Bool) throws {
        let files = try TemporaryFiles()
        var urls = [try files.file("document.txt")]
        if mixed { urls.append(try files.directory("folder")) }
        let chosen = selection(urls)
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in nil })
        let menu = try #require(builder.makeMenu(settings: Settings(targets: sampleTargets), selection: chosen, actions: &registry))
        #expect(menu.items.count == 1)
        let copy = try #require(menu.items.last)
        #expect(copy.title == (mixed ? "复制 2 个路径" : "复制路径"))
        #expect(registry.action(for: copy.tag)?.selection.pathText == chosen.pathText)
        #expect(registry.action(for: copy.tag)?.target == nil)
    }

    @Test func backgroundDirectoryShowsApplicationItems() throws {
        let files = try TemporaryFiles()
        let background = SelectionContext(selected: [try files.file("stale.txt")], targeted: files.root, isContainer: true)
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in nil })
        let menu = try #require(builder.makeMenu(settings: Settings(), selection: background, actions: &registry))
        #expect(menu.items.map(\.title) == ["用 Terminal 打开", "复制路径"])
        #expect(registry.action(for: menu.items[0].tag)?.selection.urls == [files.root])
    }

    @Test func emptySelectionProducesNoMenuAndDisabledApplicationsFallBackToCopy() {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in false }, icon: { _ in nil })
        #expect(builder.makeMenu(settings: Settings(targets: sampleTargets), selection: selection([]), actions: &registry) == nil)
        let menu = builder.makeMenu(settings: Settings(targets: sampleTargets), selection: selection([URL(fileURLWithPath: "/tmp/a")]), actions: &registry)
        #expect(menu?.items.map(\.title) == ["复制路径"])
    }

    @Test func copyOnlyMenuUsesBackgroundDirectoryAndSingleItemTitle() throws {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in false }, icon: { _ in nil })
        let background = SelectionContext(selected: [URL(fileURLWithPath: "/tmp/stale")], targeted: URL(fileURLWithPath: "/tmp/current"), isContainer: true)
        let menu = try #require(builder.makeMenu(settings: Settings(targets: sampleTargets), selection: background, actions: &registry))
        #expect(menu.items.count == 1)
        #expect(menu.items[0].title == "复制路径")
        #expect(registry.action(for: menu.items[0].tag)?.selection.pathText == "/tmp/current")
    }

    /// App icons and SF Symbols must land in the same box.
    ///
    /// They used to arrive at 16x16 and 16x18 respectively, because only the app
    /// icons were resized, which made the icon column change height between rows.
    @Test func everyMenuItemImageSharesTheSameBox() throws {
        var registry = MenuActionRegistry()
        let largeIcon = NSImage(size: NSSize(width: 512, height: 512))
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in largeIcon })
        let files = try TemporaryFiles()
        let chosen = selection([try files.directory("folder")])
        var built = builder.makeMenu(settings: Settings(targets: sampleTargets), selection: chosen, actions: &registry)
        builder.addingSettingsItem(to: &built, handler: nil, action: nil)
        let menu = try #require(built)

        // Include the folded submenu: those rows sit in the same column.
        var items = menu.items
        for item in menu.items {
            if let submenu = item.submenu { items += submenu.items }
        }
        let sizes = items.filter { !$0.isSeparatorItem }.compactMap(\.image?.size)

        #expect(sizes.count == items.filter { !$0.isSeparatorItem }.count)
        #expect(sizes.allSatisfy { $0 == NSSize(width: 16, height: 16) })
    }

    /// The Finder toolbar button is the app's only persistent entry point, so
    /// settings must be reachable even when there is no selection to act on.
    @Test func toolbarMenuKeepsSettingsReachableWithoutASelection() throws {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in nil })

        var settingsOnly: NSMenu?
        builder.addingSettingsItem(to: &settingsOnly, handler: nil, action: nil)
        #expect(settingsOnly?.items.map(\.title) == ["OneClick 设置…"])

        let files = try TemporaryFiles()
        let chosen = selection([try files.directory("folder")])
        let built = try #require(builder.makeMenu(settings: Settings(targets: sampleTargets), selection: chosen, actions: &registry))
        // The helper appends in place, so the baseline has to be captured first.
        let countBefore = built.items.count
        var withSettings: NSMenu? = built
        builder.addingSettingsItem(to: &withSettings, handler: nil, action: nil)

        #expect(withSettings === built)
        #expect(withSettings?.items.last?.title == "OneClick 设置…")
        // 不加分隔线：Finder 会保留它的占位却不画线，结果只是一块读起来像"缺了一项"
        // 的空白。设置项改用应用自身的标记与文件操作区分。
        #expect(withSettings?.items.contains { $0.isSeparatorItem } == false)
        #expect(withSettings?.items.count == countBefore + 1)
        #expect(withSettings?.items.last?.image != nil)
    }

    /// 图标颜色必须由构建菜单的一方决定，不能留给渲染方去着色。
    ///
    /// 曾经依赖 SF Symbol 的 template 染色，结果图标以定色位图的形式到达
    /// Finder（在深色外观下生成为白色），浅色菜单上就看不见了。现在颜色在构建
    /// 时烤进去，因此所有图标都必须是非 template 的 artwork。
    @Test func everyMenuImageCarriesItsOwnColour() throws {
        var registry = MenuActionRegistry()
        let artwork = NSImage(size: NSSize(width: 512, height: 512))
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in artwork })
        let files = try TemporaryFiles()
        let chosen = selection([try files.directory("folder")])
        var built = builder.makeMenu(settings: Settings(targets: sampleTargets), selection: chosen, actions: &registry)
        builder.addingSettingsItem(to: &built, handler: nil, action: nil)
        let menu = try #require(built)

        var items = menu.items
        for item in menu.items {
            if let submenu = item.submenu { items += submenu.items }
        }
        let withImages = items.filter { !$0.isSeparatorItem }
        #expect(withImages.allSatisfy { $0.image != nil })
        #expect(withImages.allSatisfy { $0.image?.isTemplate == false })
    }
}
