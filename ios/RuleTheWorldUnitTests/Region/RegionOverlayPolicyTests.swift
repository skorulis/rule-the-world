import Testing
@testable import RuleTheWorld

struct RegionOverlayPolicyTests {
    @Test func selectsStateBelowCountryThresholdAndCountriesAbove() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 500_000, previous: nil) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 749_999, previous: nil) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 750_000, previous: nil) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 6_000_000, previous: nil) == .coarse)
    }

    @Test func hysteresisPreventsThresholdFlicker() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 700_000, previous: .medium) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 680_000, previous: .medium) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 800_000, previous: .state) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 820_000, previous: .state) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 5_800_000, previous: .coarse) == .coarse)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 5_500_000, previous: .coarse) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 500_000, previous: .coarse) == .state)
    }

    @Test func invalidWidthsDisableHighlighting() {
        for width in [0.0, -1, .infinity, .nan] {
            #expect(RegionOverlayPolicy.level(visibleWidthMeters: width, previous: .coarse) == nil)
        }
    }
}
