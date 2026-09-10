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
        let menu = try #require(builder.makeMenu(settings: Settings(targets: targets, copiesPaths: false), selection: chosen, actions: &registry))
        let direct = Array(menu.items.prefix(3))
        #expect(direct.map(\.title) == targets.prefix(3).map { "在 \($0.name) 中打开" })
        #expect(direct.allSatisfy { $0.submenu == nil })
        var openItems = direct
        if count > 3 {
            #expect(menu.items.count == 4)
            #expect(menu.items[3].title == "在应用中打开")
            let submenu = try #require(menu.items[3].submenu)
            #expect(submenu.items.map(\.title) == targets.dropFirst(3).map(\.name))
            openItems += submenu.items
        } else {
            #expect(menu.items.count == 3)
        }
        #expect(openItems.compactMap { registry.action(for: $0.tag)?.target?.id } == targets.map(\.id))
        #expect(openItems.allSatisfy { registry.action(for: $0.tag)?.selection.urls == chosen.urls })
    }

    @Test func menuFiltersTargetsPreservesOrderAndSnapshotsSelection() throws {
        var settings = Settings(targets: sampleTargets)
        settings.targets.reverse()
        settings.targets[0].isEnabled = false // Claude is installed but disabled.
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { ["claude", "test-terminal", "test-vscode"].contains($0.id) }, icon: { _ in nil })
        let files = try TemporaryFiles()
        let chosen = selection([try files.directory("中文 + ' a"), try files.directory("b")])
        let menu = try #require(builder.makeMenu(settings: settings, selection: chosen, actions: &registry))
        let openItems = Array(menu.items.dropLast())
        #expect(openItems.map(\.title) == ["在 Terminal 中打开", "在 Visual Studio Code 中打开"])
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
        #expect(copy.title == (mixed ? "复制 2 个绝对路径" : "复制绝对路径"))
        #expect(registry.action(for: copy.tag)?.selection.pathText == chosen.pathText)
        #expect(registry.action(for: copy.tag)?.target == nil)
        #expect(builder.makeMenu(settings: Settings(targets: sampleTargets, copiesPaths: false), selection: chosen, actions: &registry) == nil)
    }

    @Test func backgroundDirectoryShowsApplicationItems() throws {
        let files = try TemporaryFiles()
        let background = SelectionContext(selected: [try files.file("stale.txt")], targeted: files.root, isContainer: true)
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in true }, icon: { _ in nil })
        let menu = try #require(builder.makeMenu(settings: Settings(copiesPaths: false), selection: background, actions: &registry))
        #expect(menu.items.map(\.title) == ["在 Claude Code 中打开"])
        #expect(registry.action(for: menu.items[0].tag)?.selection.urls == [files.root])
    }

    @Test func emptySelectionAndDisabledActionsProduceNoMenu() {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in false }, icon: { _ in nil })
        #expect(builder.makeMenu(settings: Settings(targets: sampleTargets), selection: selection([]), actions: &registry) == nil)
        #expect(builder.makeMenu(settings: Settings(copiesPaths: false), selection: selection([URL(fileURLWithPath: "/tmp/a")]), actions: &registry) == nil)
    }

    @Test func copyOnlyMenuUsesBackgroundDirectoryAndSingleItemTitle() throws {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in false }, icon: { _ in nil })
        let background = SelectionContext(selected: [URL(fileURLWithPath: "/tmp/stale")], targeted: URL(fileURLWithPath: "/tmp/current"), isContainer: true)
        let menu = try #require(builder.makeMenu(settings: Settings(targets: sampleTargets), selection: background, actions: &registry))
        #expect(menu.items.count == 1)
        #expect(menu.items[0].title == "复制绝对路径")
        #expect(registry.action(for: menu.items[0].tag)?.selection.pathText == "/tmp/current")
    }
}
