import Foundation
import Testing
@testable import OneClickCore

/// `ApplicationResolver` is the last gate before a click launches a binary, and
/// it had no coverage of its own — every other test injects a stand-in. These
/// pin the rule that only the path the user chose is opened, so a bundle
/// claiming a known identifier cannot take the action over while the menu still
/// shows the name the user picked.
@MainActor
struct ApplicationResolverTests {
    private func target(_ url: URL?, identifier: String?, kind: TargetKind = .application) -> OpenTarget {
        OpenTarget(id: "test", name: "Test", kind: kind, bundleIdentifier: identifier, applicationURL: url, isEnabled: true)
    }

    @Test func anImportedApplicationResolvesFromItsStoredPath() throws {
        let files = try TemporaryFiles()
        let application = try files.application("My Editor", identifier: "test.editor")

        let resolved = ApplicationResolver().applicationURL(for: target(application, identifier: "test.editor"))

        #expect(resolved == application)
    }

    @Test func aStoredPathThatNoLongerExistsIsNeverReplacedByABundleIdentifierLookup() throws {
        let files = try TemporaryFiles()
        let missing = files.root.appendingPathComponent("Gone.app", isDirectory: true)

        // The identifier names a real system application. A fallback lookup
        // would find it and open something the user never selected.
        let resolved = ApplicationResolver().applicationURL(for: target(missing, identifier: "com.apple.Terminal"))

        #expect(resolved == nil)
    }

    @Test func aStoredPathWhoseBundleIdentifierDoesNotMatchTheTargetIsRefused() throws {
        let files = try TemporaryFiles()
        let application = try files.application("My Editor", identifier: "test.editor")

        let resolved = ApplicationResolver().applicationURL(for: target(application, identifier: "com.example.other"))

        #expect(resolved == nil)
    }

    @Test func terminalResolvesFromItsFixedSystemPath() throws {
        let terminal = try #require(OpenTarget.builtIns.first { $0.kind == .terminal })

        let resolved = try #require(ApplicationResolver().applicationURL(for: terminal))

        #expect(resolved.path == "/System/Applications/Utilities/Terminal.app")
        #expect(Bundle(url: resolved)?.bundleIdentifier == "com.apple.Terminal")
    }

    @Test func anApplicationTargetWithoutAStoredPathDoesNotResolve() {
        let resolved = ApplicationResolver().applicationURL(for: target(nil, identifier: "com.apple.TextEdit"))

        #expect(resolved == nil)
    }
}
