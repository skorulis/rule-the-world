import Foundation
import Testing
@testable import RuleTheWorld

struct HexElevationPolicyTests {
    @Test func equalScoresAreFlat() {
        #expect(HexElevationPolicy.level(userScore: 0, rivalScore: 0) == 0)
        #expect(HexElevationPolicy.level(userScore: 2, rivalScore: 2) == 0)
        #expect(HexElevationPolicy.level(userScore: 0.5, rivalScore: 0.5) == 0)
    }

    @Test func marginThresholds() {
        #expect(HexElevationPolicy.level(userScore: 1, rivalScore: 0) == 1)
        #expect(HexElevationPolicy.level(userScore: 3, rivalScore: 0) == 2)
        #expect(HexElevationPolicy.level(userScore: 6, rivalScore: 0) == 3)
        #expect(HexElevationPolicy.level(userScore: 10, rivalScore: 0) == 4)
        #expect(HexElevationPolicy.level(userScore: 50, rivalScore: 0) == 4)
    }

    @Test func marginIsSymmetric() {
        #expect(HexElevationPolicy.level(userScore: 0, rivalScore: 3) == 2)
        #expect(HexElevationPolicy.level(userScore: 2, rivalScore: 8) == 3)
    }

    @Test func boundaryValuesJustBelowThreshold() {
        #expect(HexElevationPolicy.level(userScore: 0.99, rivalScore: 0) == 0)
        #expect(HexElevationPolicy.level(userScore: 2.99, rivalScore: 0) == 1)
    }
}
