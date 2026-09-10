import Foundation
import Testing
@testable import OneClickCore

@Test func enqueueCreatesAUUIDNamedRequestFile() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let id = try repository.enqueue(
            targetID: "terminal",
            urls: [URL(fileURLWithPath: "/tmp/project", isDirectory: true)],
            now: Date(timeIntervalSince1970: 2_000_000_000)
        )

        let filenames = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(filenames == ["open-\(id.uuidString).json"])
        #expect(UUID(uuidString: id.uuidString) == id)
    }
}

@Test func enqueueRemovesOnlyStaleUUIDRequestFiles() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let staleURL = directory.appendingPathComponent("open-\(UUID().uuidString).json")
        let freshURL = directory.appendingPathComponent("open-\(UUID().uuidString).json")
        let similarURL = directory.appendingPathComponent("open-not-a-uuid.json")
        let unrelatedURL = directory.appendingPathComponent("notes.json")
        for url in [staleURL, freshURL, similarURL, unrelatedURL] {
            try Data("fixture".utf8).write(to: url)
        }
        try FileManager.default.setAttributes(
            [.modificationDate: now.addingTimeInterval(-121)],
            ofItemAtPath: staleURL.path
        )
        for url in [freshURL, similarURL, unrelatedURL] {
            try FileManager.default.setAttributes(
                [.modificationDate: now.addingTimeInterval(-30)],
                ofItemAtPath: url.path
            )
        }

        _ = try repository.enqueue(
            targetID: "terminal",
            urls: [URL(fileURLWithPath: "/tmp/project")],
            now: now
        )

        #expect(!FileManager.default.fileExists(atPath: staleURL.path))
        #expect(FileManager.default.fileExists(atPath: freshURL.path))
        #expect(FileManager.default.fileExists(atPath: similarURL.path))
        #expect(FileManager.default.fileExists(atPath: unrelatedURL.path))
    }
}

@Test func consumeReturnsTheRequestExactlyOnce() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let createdAt = Date(timeIntervalSince1970: 2_000_000_000)
        let urls = [
            URL(fileURLWithPath: "/tmp/first file.swift"),
            URL(fileURLWithPath: "/tmp/中文-project", isDirectory: true),
        ]
        let id = try repository.enqueue(
            targetID: "vscode",
            urls: urls,
            now: createdAt
        )

        let request = try repository.consume(id: id, now: createdAt.addingTimeInterval(30))

        #expect(request.targetID == "vscode")
        #expect(request.urls == urls)
        #expect(request.createdAt == createdAt)
        #expect(throws: (any Error).self) {
            try repository.consume(id: id, now: createdAt.addingTimeInterval(31))
        }
    }
}

@Test func enqueueRejectsEmptyRoutingDataAndNonlocalURLs() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let local = URL(fileURLWithPath: "/tmp/project")
        let remote = try #require(URL(string: "https://example.com/project"))
        let emptyPath = try #require(URL(string: "file:"))

        #expect(throws: (any Error).self) {
            try repository.enqueue(targetID: "  ", urls: [local])
        }
        #expect(throws: (any Error).self) {
            try repository.enqueue(targetID: "terminal", urls: [])
        }
        #expect(throws: (any Error).self) {
            try repository.enqueue(targetID: "terminal", urls: [remote])
        }
        #expect(throws: (any Error).self) {
            try repository.enqueue(targetID: "terminal", urls: [emptyPath])
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}

@Test func consumeRejectsAndRemovesInvalidPersistedRequests() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let invalidRequests = [
            OpenRequest(
                targetID: "",
                urls: [URL(fileURLWithPath: "/tmp/project")],
                createdAt: now
            ),
            OpenRequest(
                targetID: "terminal",
                urls: [],
                createdAt: now
            ),
            OpenRequest(
                targetID: "terminal",
                urls: [try #require(URL(string: "file://server.example.com/Volumes/project"))],
                createdAt: now
            ),
            OpenRequest(
                targetID: "terminal",
                urls: [try #require(URL(string: "file:"))],
                createdAt: now
            ),
        ]

        for request in invalidRequests {
            let id = UUID()
            let fileURL = directory.appendingPathComponent("open-\(id.uuidString).json")
            try JSONEncoder().encode(request).write(to: fileURL)

            #expect(throws: (any Error).self) {
                try repository.consume(id: id, now: now)
            }
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }
}

@Test func consumeRejectsAndRemovesStaleRequests() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let createdAt = Date(timeIntervalSince1970: 2_000_000_000)
        let id = try repository.enqueue(
            targetID: "claude",
            urls: [URL(fileURLWithPath: "/tmp/project", isDirectory: true)],
            now: createdAt
        )
        let fileURL = directory.appendingPathComponent("open-\(id.uuidString).json")

        #expect(throws: (any Error).self) {
            try repository.consume(id: id, now: createdAt.addingTimeInterval(121))
        }
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }
}

@Test func consumeAllowsSmallClockSkewFromTheFuture() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let id = try repository.enqueue(
            targetID: "cursor",
            urls: [URL(fileURLWithPath: "/tmp/project")],
            now: now.addingTimeInterval(5)
        )

        let request = try repository.consume(id: id, now: now)

        #expect(request.targetID == "cursor")
    }
}

@Test func consumeRejectsAndRemovesMalformedOrOversizedFiles() throws {
    try withOpenRequestFixture { directory in
        let repository = OpenRequestRepository(directory: directory)
        let malformedID = UUID()
        let malformedURL = directory.appendingPathComponent(
            "open-\(malformedID.uuidString).json"
        )
        try Data("not-json".utf8).write(to: malformedURL)

        #expect(throws: (any Error).self) {
            try repository.consume(id: malformedID)
        }
        #expect(!FileManager.default.fileExists(atPath: malformedURL.path))

        let oversizedID = UUID()
        let oversizedURL = directory.appendingPathComponent(
            "open-\(oversizedID.uuidString).json"
        )
        try Data(repeating: 0x78, count: 1_048_577).write(to: oversizedURL)

        #expect(throws: (any Error).self) {
            try repository.consume(id: oversizedID)
        }
        #expect(!FileManager.default.fileExists(atPath: oversizedURL.path))
    }
}

private func withOpenRequestFixture(_ body: (URL) throws -> Void) throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("OneClickOpenRequests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try body(directory)
}
