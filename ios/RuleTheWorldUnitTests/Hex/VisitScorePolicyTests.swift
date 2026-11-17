import Testing
@testable import RuleTheWorld

struct VisitScorePolicyTests {
    @Test(arguments: [
        (10.0, 1.0),
        (20.0, 0.5),
        (30.0, 0.5),
        (50.0, 0.25),
        (100.0, 0.25),
        (150.0, 0.0),
        (200.0, 0.0)
    ])
    func scoreForSpeed(kmh: Double, expected: Double) {
        #expect(VisitScorePolicy.score(forSpeed: kmh / 3.6) == expected)
    }

    @Test func nilSpeedScoresOne() {
        #expect(VisitScorePolicy.score(forSpeed: nil) == 1)
    }

    @Test func accuracyGate() {
        func sample(_ accuracy: Double) -> LocationSample {
            LocationSample(
                latitude: 0,
                longitude: 0,
                speed: nil,
                course: nil,
                horizontalAccuracy: accuracy,
                timestamp: .now
            )
        }
        #expect(VisitScorePolicy.isAcceptable(sample(10)))
        #expect(VisitScorePolicy.isAcceptable(sample(100)))
        #expect(!VisitScorePolicy.isAcceptable(sample(150)))
        #expect(!VisitScorePolicy.isAcceptable(sample(-1)))
    }
}
