import Foundation
import Testing
@testable import OneClickCore

/// `last-error.txt` is a channel anyone running as this user can write to, and
/// its contents are rendered in the settings alert. These cover the two
/// ceilings that keep that channel from being used against the user: the text
/// is bounded before it is shown, and the file is read with a byte limit rather
/// than loaded whole.
@Suite struct SharedEnvironmentErrorTests {
    @Test func errorTextIsTruncatedBeforeItIsWrittenSoAHostileMessageCannotReachTheAlert() {
        let hostile = String(repeating: "a", count: 5000)

        let bounded = SharedEnvironment.boundedErrorText(hostile)

        #expect(bounded.count == SharedEnvironment.errorTextCharacterLimit + 1)
        #expect(bounded.hasSuffix("…"))
    }

    @Test func shortErrorMessagesArePassedThroughUnchanged() {
        let message = PlatformError.applicationUnavailable("Visual Studio Code").localizedDescription

        #expect(SharedEnvironment.boundedErrorText(message) == message)
    }

    @Test func aHugeErrorFileIsReadWithAByteLimitInsteadOfBeingLoadedWhole() throws {
        let files = try TemporaryFiles()
        let url = files.root.appendingPathComponent("last-error.txt")
        try Data(String(repeating: "x", count: 10_000).utf8).write(to: url)

        let text = try #require(SharedEnvironment.errorText(readingFrom: url, limit: 64))

        #expect(text.count == 64)
    }

    @Test func invalidUTF8InTheErrorFileStillProducesAMessage() throws {
        let files = try TemporaryFiles()
        let url = files.root.appendingPathComponent("last-error.txt")
        try Data([0xFF, 0xFE, 0x41]).write(to: url)

        let text = try #require(SharedEnvironment.errorText(readingFrom: url))

        #expect(text.contains("A"))
    }

    @Test func anEmptyOrUnreadableErrorFileReportsNothing() throws {
        let files = try TemporaryFiles()
        let empty = files.root.appendingPathComponent("last-error.txt")
        try Data().write(to: empty)

        #expect(SharedEnvironment.errorText(readingFrom: empty) == nil)
        #expect(SharedEnvironment.errorText(readingFrom: files.root.appendingPathComponent("missing.txt")) == nil)
    }
}
