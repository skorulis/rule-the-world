import Testing
@testable import RuleTheWorld

struct RegionOverlayPolicyTests {
    @Test func selectsStateBelowCountryThresholdAndCountriesAbove() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 500_000, previous: nil) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 749_999, previous: nil) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 750_000, previous: nil) == .medium)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 6_000_000, previous: nil) == .coarse)
    }

    @Test func selectsSuburbBelowStateThreshold() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 59_999, previous: nil) == .suburb)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 60_000, previous: nil) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 10_000, previous: nil) == .suburb)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 500, previous: nil) == .suburb)
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

    @Test func hysteresisPreventsSuburbThresholdFlicker() {
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 63_000, previous: .suburb) == .suburb)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 66_000, previous: .suburb) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 57_000, previous: .state) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 54_000, previous: .state) == .suburb)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 800_000, previous: .suburb) == .state)
        #expect(RegionOverlayPolicy.level(visibleWidthMeters: 820_000, previous: .suburb) == .medium)
    }

    @Test func invalidWidthsDisableHighlighting() {
        for width in [0.0, -1, .infinity, .nan] {
            #expect(RegionOverlayPolicy.level(visibleWidthMeters: width, previous: .coarse) == nil)
        }
    }
}
