import Foundation
import Testing
@testable import OneClickCore

@Test func claudeLinkRoundTripsDirectoryWithSpecialCharacters() throws {
    let directory = URL(fileURLWithPath: "/tmp/中文 O'Brien & #project", isDirectory: true)
    let url = try ClaudeLink.make(directory: directory)
    let parts = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))

    #expect(parts.scheme == "claude-cli")
    #expect(parts.host == "open")
    #expect(parts.queryItems == [URLQueryItem(name: "cwd", value: directory.path)])
}

@Test func claudeLinkAcceptsExplicitLocalhostFileURL() throws {
    let directory = try #require(URL(string: "file://localhost/tmp/project"))
    let parts = try #require(
        URLComponents(
            url: ClaudeLink.make(directory: directory),
            resolvingAgainstBaseURL: false
        )
    )

    #expect(parts.queryItems == [URLQueryItem(name: "cwd", value: "/tmp/project")])
}

@Test func claudeLinkPercentEncodesLiteralPlusSigns() throws {
    let directory = URL(fileURLWithPath: "/tmp/C++ + tools", isDirectory: true)
    let parts = try #require(
        URLComponents(
            url: ClaudeLink.make(directory: directory),
            resolvingAgainstBaseURL: false
        )
    )

    #expect(parts.percentEncodedQuery == "cwd=/tmp/C%2B%2B%20%2B%20tools")
    #expect(parts.percentEncodedQuery?.contains("+") == false)
    #expect(parts.queryItems == [URLQueryItem(name: "cwd", value: "/tmp/C++ + tools")])
}

@Test(arguments: [
    "https://example.com/project",
    "file://server.example.com/Volumes/project",
    "file:///tmp/parent/../project",
    "file:///tmp/project%0Ahidden",
    "file:///tmp/project%E2%80%AEtxt",
])
func claudeLinkRejectsUnsupportedLocations(_ rawURL: String) throws {
    let directory = try #require(URL(string: rawURL))

    #expect(throws: (any Error).self) {
        try ClaudeLink.make(directory: directory)
    }
}
