import AppKit
import Testing
@testable import OneClickCore

@Suite @MainActor
struct TargetAvailabilityCacheTests {
    @Test func resolvingTheSameTargetTwiceOnlyHitsTheResolverOnce() {
        var resolutions = 0
        let expected = URL(fileURLWithPath: "/Applications/Test.app")
        let cache = TargetAvailabilityCache { _ in
            resolutions += 1
            return expected
        }

        #expect(cache.applicationURL(for: sampleTargets[0]) == expected)
        #expect(cache.applicationURL(for: sampleTargets[0]) == expected)
        #expect(resolutions == 1)
    }

    /// A negative result must not be remembered: installing an application while
    /// the extension is running has to show up without restarting Finder.
    @Test func missingTargetsAreRecheckedSoANewInstallIsPickedUp() {
        var resolutions = 0
        let cache = TargetAvailabilityCache { _ in
            resolutions += 1
            return nil
        }

        #expect(cache.applicationURL(for: sampleTargets[0]) == nil)
        #expect(cache.applicationURL(for: sampleTargets[0]) == nil)
        #expect(resolutions == 2)
    }

    @Test func invalidateDropsResolvedApplications() {
        var resolutions = 0
        let cache = TargetAvailabilityCache { _ in
            resolutions += 1
            return URL(fileURLWithPath: "/Applications/Test.app")
        }

        _ = cache.applicationURL(for: sampleTargets[0])
        cache.invalidate()
        _ = cache.applicationURL(for: sampleTargets[0])
        #expect(resolutions == 2)
    }

    @Test func iconsAreResolvedOnceAndReused() throws {
        let application = URL(fileURLWithPath: "/Applications/Test.app")
        let icon = NSImage()
        var iconResolutions = 0
        let cache = TargetAvailabilityCache(resolve: { _ in application }) { _ in
            iconResolutions += 1
            return icon
        }

        let first = try #require(cache.icon(for: sampleTargets[0]))
        let second = try #require(cache.icon(for: sampleTargets[0]))
        #expect(first === second)
        #expect(iconResolutions == 1)
    }
}
