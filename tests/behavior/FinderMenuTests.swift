import AppKit
import Testing
@testable import OneClickCore

@Suite @MainActor
struct FinderMenuTests {
    @Test func menuFiltersTargetsPreservesOrderAndSnapshotsSelection() throws {
        var settings = Settings()
        settings.targets.reverse()
        settings.targets[0].isEnabled = false // Claude is installed but disabled.
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { ["claude", "terminal", "vscode"].contains($0.id) }, icon: { _ in nil })
        let chosen = selection([URL(fileURLWithPath: "/tmp/中文 + ' a"), URL(fileURLWithPath: "/tmp/b")])
        let menu = try #require(builder.makeMenu(settings: settings, selection: chosen, actions: &registry))
        let submenu = try #require(menu.items.first?.submenu)
        #expect(submenu.items.map(\.title) == ["Terminal", "Visual Studio Code"])
        #expect(submenu.items.allSatisfy { $0.tag > 0 })
        #expect(Set(submenu.items.map(\.tag)).count == 2)
        let action = try #require(registry.action(for: submenu.items[0].tag))
        #expect(action.target?.id == "terminal")
        #expect(action.selection.urls.map(\.path) == ["/tmp/中文 + ' a", "/tmp/b"])
        let copy = try #require(menu.items.last)
        #expect(copy.title.contains("2"))
        #expect(registry.action(for: copy.tag)?.target == nil)
        #expect(registry.action(for: copy.tag)?.selection.pathText == "/tmp/中文 + ' a\n/tmp/b")
    }

    @Test func emptySelectionAndDisabledActionsProduceNoMenu() {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in false }, icon: { _ in nil })
        #expect(builder.makeMenu(settings: Settings(), selection: selection([]), actions: &registry) == nil)
        #expect(builder.makeMenu(settings: Settings(copiesPaths: false), selection: selection([URL(fileURLWithPath: "/tmp/a")]), actions: &registry) == nil)
    }

    @Test func copyOnlyMenuUsesBackgroundDirectoryAndSingleItemTitle() throws {
        var registry = MenuActionRegistry()
        let builder = FinderMenuBuilder(available: { _ in false }, icon: { _ in nil })
        let background = SelectionContext(selected: [URL(fileURLWithPath: "/tmp/stale")], targeted: URL(fileURLWithPath: "/tmp/current"), isContainer: true)
        let menu = try #require(builder.makeMenu(settings: Settings(), selection: background, actions: &registry))
        #expect(menu.items.count == 1)
        #expect(menu.items[0].title == "复制绝对路径")
        #expect(registry.action(for: menu.items[0].tag)?.selection.pathText == "/tmp/current")
    }
}
