import Testing
@testable import RuleTheWorld

struct RegionOverlayPolicyTests {
    @Test func highlightsOnlyAtCountryScale() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 500_000, previous: nil) == nil)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 1_499_999, previous: nil) == nil)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 1_500_000, previous: nil) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 6_000_000, previous: nil) == .coarse)
    }

    @Test func hysteresisPreventsThresholdFlicker() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 1_450_000, previous: .medium) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 1_350_000, previous: .medium) == nil)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 5_800_000, previous: .coarse) == .coarse)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 5_500_000, previous: .coarse) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 1_000_000, previous: .coarse) == nil)
    }

    @Test func invalidWidthsDisableHighlighting() {
        for width in [0.0, -1, .infinity, .nan] {
            #expect(RegionOverlayPolicy.level(visibleWidthMeters: width, previous: .coarse) == nil)
        }
    }
}
