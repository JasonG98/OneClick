import Foundation
import Testing
@testable import OneClickCore

@Test func copyPreservesNamesAndSelectionOrder() {
    let first = URL(fileURLWithPath: "/tmp/中文 O'Brien & #notes.txt")
    let second = URL(fileURLWithPath: "/tmp/second.txt")
    let selection = SelectionContext(
        selected: [first, second],
        targeted: nil,
        isContainer: false
    )

    #expect(selection.pathText == "/tmp/中文 O'Brien & #notes.txt\n/tmp/second.txt")
}

@Test func containerUsesCurrentFolderAndIgnoresStaleSelection() {
    let current = URL(fileURLWithPath: "/tmp/current", isDirectory: true)
    let stale = URL(fileURLWithPath: "/tmp/stale.txt")
    let selection = SelectionContext(
        selected: [stale],
        targeted: current,
        isContainer: true
    )

    #expect(selection.urls == [current])
}

@Test func itemMenuFallsBackToTargetOnlyForEmptySelection() throws {
    let selected = URL(fileURLWithPath: "/tmp/selected.txt")
    let targeted = URL(fileURLWithPath: "/tmp/targeted.txt")

    #expect(
        SelectionContext(selected: [selected], targeted: targeted, isContainer: false).urls
            == [selected]
    )
    #expect(
        SelectionContext(selected: [], targeted: targeted, isContainer: false).urls
            == [targeted]
    )
    #expect(
        SelectionContext(selected: [], targeted: nil, isContainer: false).urls.isEmpty
    )
    #expect(
        try SelectionContext(selected: [], targeted: nil, isContainer: false)
            .workingDirectories().isEmpty
    )
}

@Test func workingDirectoriesUseFileParentsAndDeduplicateInOrder() throws {
    try withFixture { root in
        let firstDirectory = root.appendingPathComponent("first", isDirectory: true)
        let secondDirectory = root.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(at: firstDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondDirectory, withIntermediateDirectories: true)
        let firstFile = firstDirectory.appendingPathComponent("a.txt")
        let secondFile = firstDirectory.appendingPathComponent("b.txt")
        let thirdFile = secondDirectory.appendingPathComponent("c.txt")
        try Data("a".utf8).write(to: firstFile)
        try Data("b".utf8).write(to: secondFile)
        try Data("c".utf8).write(to: thirdFile)

        let selection = SelectionContext(
            selected: [firstFile, firstDirectory, secondFile, thirdFile],
            targeted: nil,
            isContainer: false
        )

        #expect(try selection.workingDirectories() == [firstDirectory, secondDirectory])
    }
}

@Test func workingDirectoriesPreserveDirectorySymlinkPath() throws {
    try withFixture { root in
        let real = root.appendingPathComponent("real", isDirectory: true)
        let link = root.appendingPathComponent("project-link", isDirectory: true)
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        let selection = SelectionContext(selected: [link], targeted: nil, isContainer: false)

        #expect(selection.pathText == link.path)
        #expect(try selection.workingDirectories() == [link])
    }
}

@Test func workingDirectoriesAllowApplicationBundlesAsFolders() throws {
    try withFixture { root in
        let application = root.appendingPathComponent("Sample.app", isDirectory: true)
        try FileManager.default.createDirectory(at: application, withIntermediateDirectories: true)

        let selection = SelectionContext(selected: [application], targeted: nil, isContainer: false)

        #expect(try selection.workingDirectories() == [application])
    }
}

@Test func workingDirectoriesRejectMissingAndNonFileURLs() throws {
    try withFixture { root in
        let missing = root.appendingPathComponent("missing.txt")
        let remote = try #require(URL(string: "https://example.com/project"))

        #expect(throws: (any Error).self) {
            try SelectionContext(selected: [missing], targeted: nil, isContainer: false)
                .workingDirectories()
        }
        #expect(throws: (any Error).self) {
            try SelectionContext(selected: [remote], targeted: nil, isContainer: false)
                .workingDirectories()
        }
    }
}

private func withFixture(_ body: (URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("OneClickCoreTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try body(root)
}
