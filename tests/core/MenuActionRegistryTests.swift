import Foundation
import Testing
@testable import OneClickCore

@Test func registryKeepsIndependentImmutableSnapshots() throws {
    let firstSelection = SelectionContext(
        selected: [URL(fileURLWithPath: "/tmp/first project/file.swift")],
        targeted: nil,
        isContainer: false
    )
    let secondSelection = SelectionContext(
        selected: [URL(fileURLWithPath: "/tmp/second/README.md")],
        targeted: nil,
        isContainer: false
    )
    var firstTarget = OpenTarget(id: "vscode", name: "Code", kind: .application, bundleIdentifier: "com.microsoft.VSCode", isEnabled: true)
    var registry = MenuActionRegistry()

    let firstTag = registry.insert(selection: firstSelection, target: firstTarget)
    firstTarget.id = "mutated-after-insert"
    let secondTag = registry.insert(selection: secondSelection, target: OpenTarget(id: "cursor", name: "Cursor", kind: .application, bundleIdentifier: "com.todesktop.230313mzl4w4u92", isEnabled: true))

    let retainedFirst = try #require(registry.action(for: firstTag))
    let retainedSecond = try #require(registry.action(for: secondTag))
    #expect(firstTag == 1)
    #expect(secondTag == 2)
    #expect(retainedFirst.selection.pathText == "/tmp/first project/file.swift")
    #expect(retainedFirst.target?.id == "vscode")
    #expect(retainedSecond.selection.pathText == "/tmp/second/README.md")
    #expect(retainedSecond.target?.id == "cursor")
}

@Test func registryStoresCopyActionsWithoutATarget() throws {
    let selection = SelectionContext(
        selected: [URL(fileURLWithPath: "/tmp/中文 & notes.txt")],
        targeted: nil,
        isContainer: false
    )
    var registry = MenuActionRegistry()

    let tag = registry.insert(selection: selection, target: nil)

    let action = try #require(registry.action(for: tag))
    #expect(action.selection.pathText == "/tmp/中文 & notes.txt")
    #expect(action.target == nil)
}

@Test func registryReturnsNilForUnknownTags() {
    var registry = MenuActionRegistry()
    _ = registry.insert(
        selection: SelectionContext(
            selected: [URL(fileURLWithPath: "/tmp/known")],
            targeted: nil,
            isContainer: false
        ),
        target: nil
    )

    #expect(registry.action(for: 0) == nil)
    #expect(registry.action(for: 999) == nil)
}

@Test func registryEvictsTheOldestSnapshotAtCapacity() throws {
    var registry = MenuActionRegistry(capacity: 2)
    let first = registry.insert(selection: selection("/tmp/first"), target: nil)
    let second = registry.insert(selection: selection("/tmp/second"), target: nil)
    let third = registry.insert(selection: selection("/tmp/third"), target: nil)

    #expect((first, second, third) == (1, 2, 3))
    #expect(registry.action(for: first) == nil)
    #expect(try #require(registry.action(for: second)).selection.pathText == "/tmp/second")
    #expect(try #require(registry.action(for: third)).selection.pathText == "/tmp/third")
}

private func selection(_ path: String) -> SelectionContext {
    SelectionContext(
        selected: [URL(fileURLWithPath: path)],
        targeted: nil,
        isContainer: false
    )
}
