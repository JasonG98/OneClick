import Foundation
import Testing
@testable import OneClickCore

struct SharedDirectoryTests {
    private func withHome(_ body: (URL) throws -> Void) throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        try body(home)
    }

    @Test func independentClientsShareSettingsAndConsumeErrors() throws {
        try withHome { home in
            let app = try SharedDirectory.prepare(homePath: home.path)
            let finder = try SharedDirectory.prepare(homePath: home.path)
            #expect(app.path == home.appendingPathComponent("Library/Application Support/OneClick").path)
            #expect(app == finder)
            let repository = SettingsRepository(fileURL: app.appendingPathComponent("settings.json"))
            var settings = Settings()
            settings.directories = [home]
            try repository.save(settings)
            let loaded = try SettingsRepository(fileURL: finder.appendingPathComponent("settings.json")).load()
            #expect(loaded == settings)
            SharedEnvironment.report(PlatformError.emptySelection, in: finder)
            #expect(SharedEnvironment.takeError(in: app) == PlatformError.emptySelection.localizedDescription)
            #expect(SharedEnvironment.takeError(in: app) == nil)
            let owner = NSDictionary(contentsOf: app.appendingPathComponent(".oneclick-owner.plist"))
            #expect(owner?["CFBundleIdentifier"] as? String == "local.oneclick.app")
        }
    }

    @Test(arguments: [nil, "", "relative/home", "/", "/tmp/../tmp/home"] as [String?])
    func invalidAccountHomeFailsClosed(_ path: String?) {
        #expect(throws: PlatformError.sharedDirectoryUnavailable) {
            try SharedDirectory.prepare(homePath: path)
        }
    }

    @Test func neverScansLegacyContainers() throws {
        try withHome { home in
            let legacy = home.appendingPathComponent("Library/Group Containers/legacy.local.oneclick.shared")
            try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
            try Data("old settings".utf8).write(to: legacy.appendingPathComponent("settings.json"))
            let directory = try SharedDirectory.prepare(homePath: home.path)
            #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings.json").path))
            #expect(try String(contentsOf: legacy.appendingPathComponent("settings.json"), encoding: .utf8) == "old settings")
        }
    }

    @Test func refusesNonemptyUnownedDirectory() throws {
        try withHome { home in
            let directory = home.appendingPathComponent("Library/Application Support/OneClick")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("foreign".utf8).write(to: directory.appendingPathComponent("settings.json"))
            #expect(throws: PlatformError.sharedDirectoryUnavailable) {
                try SharedDirectory.prepare(homePath: home.path)
            }
            #expect(try String(contentsOf: directory.appendingPathComponent("settings.json"), encoding: .utf8) == "foreign")
        }
    }

    @Test func refusesForeignMarkerAndSymlinkDirectory() throws {
        try withHome { home in
            let directory = try SharedDirectory.prepare(homePath: home.path)
            let marker = directory.appendingPathComponent(".oneclick-owner.plist")
            let data = try PropertyListSerialization.data(fromPropertyList: ["CFBundleIdentifier": "another.app"], format: .xml, options: 0)
            try data.write(to: marker)
            #expect(throws: PlatformError.sharedDirectoryUnavailable) {
                try SharedDirectory.prepare(homePath: home.path)
            }
            let other = home.appendingPathComponent("other")
            try FileManager.default.moveItem(at: directory, to: other)
            try FileManager.default.createSymbolicLink(at: directory, withDestinationURL: other)
            #expect(throws: PlatformError.sharedDirectoryUnavailable) {
                try SharedDirectory.prepare(homePath: home.path)
            }
        }
    }

    @Test func directoryCreationFailureIsActionable() throws {
        try withHome { home in
            try Data().write(to: home.appendingPathComponent("Library"))
            #expect(throws: PlatformError.sharedDirectoryUnavailable) {
                try SharedDirectory.prepare(homePath: home.path)
            }
            #expect(!PlatformError.sharedDirectoryUnavailable.localizedDescription.contains("DEVELOPMENT_TEAM"))
        }
    }
}
