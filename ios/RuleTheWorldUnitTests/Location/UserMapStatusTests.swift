import Foundation
import Testing
@testable import RuleTheWorld

struct UserMapStatusTests {
    private func sample(speed: Double?, course: Double?) -> LocationSample {
        LocationSample(
            latitude: -33.89,
            longitude: 151.19,
            speed: speed,
            course: course,
            horizontalAccuracy: 10,
            timestamp: .now
        )
    }

    @Test func movingSampleKeepsCompassHeading() {
        let status = UserMapStatus.make(sample: sample(speed: 4, course: 90), heading: 45)
        #expect(status?.directionDegrees == 45)
        #expect(status?.speedKmh == 14.4)
    }

    @Test func stationarySampleUsesHeading() {
        let status = UserMapStatus.make(sample: sample(speed: 0.2, course: 90), heading: 45)
        #expect(status?.directionDegrees == 45)
    }

    @Test func movingWithoutHeadingHasNilDirection() {
        let status = UserMapStatus.make(sample: sample(speed: 4, course: 90), heading: nil)
        #expect(status?.directionDegrees == nil)
    }

    @Test func stationaryWithoutHeadingHasNilDirection() {
        let status = UserMapStatus.make(sample: sample(speed: nil, course: nil), heading: nil)
        #expect(status?.directionDegrees == nil)
    }

    @Test func zeroSpeedGivesNilSpeedKmh() {
        let status = UserMapStatus.make(sample: sample(speed: 0, course: nil), heading: nil)
        #expect(status?.speedKmh == nil)
    }

    @Test func nilSampleGivesNilStatus() {
        #expect(UserMapStatus.make(sample: nil, heading: 45) == nil)
    }
}
