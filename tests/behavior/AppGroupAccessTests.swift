import Foundation
import Testing
@testable import OneClickCore

struct AppGroupAccessTests {
    @Test(arguments: [
        (nil, nil), ("TEAM123456.local.oneclick.shared", nil),
        (nil, "TEAM123456"), ("OTHER12345.local.oneclick.shared", "TEAM123456"),
        ("TEAM123456extra.local.oneclick.shared", "TEAM123456"),
        (".local.oneclick.shared", "")
    ] as [(String?, String?)])
    func invalidSigningNeverTouchesProtectedContainer(identifier: String?, team: String?) {
        var accesses = 0
        #expect(throws: PlatformError.sharedContainerUnavailable) {
            try SharedEnvironment.containerURL(identifier: identifier, signingTeam: team) { _ in
                accesses += 1
                return URL(fileURLWithPath: "/tmp/group")
            }
        }
        #expect(accesses == 0)
    }

    @Test func validTeamResolvesOnlyItsConfiguredGroup() throws {
        var requested: [String] = []
        let url = try SharedEnvironment.containerURL(identifier: "TEAM123456.local.oneclick.shared", signingTeam: "TEAM123456") {
            requested.append($0)
            return URL(fileURLWithPath: "/tmp/group")
        }
        #expect(url.path == "/tmp/group")
        #expect(requested == ["TEAM123456.local.oneclick.shared"])
    }

    @Test func unavailableContainerReturnsAnActionableError() {
        #expect(throws: PlatformError.sharedContainerUnavailable) {
            try SharedEnvironment.containerURL(identifier: "TEAM123456.local.oneclick.shared", signingTeam: "TEAM123456") { _ in nil }
        }
    }
}
