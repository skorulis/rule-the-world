import CoreLocation
import Testing
@testable import RuleTheWorld

struct LocationSampleTests {
    @Test func unknownSpeedMapsToNil() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let sample = LocationSample(location: location)
        #expect(sample.speed == nil)
        #expect(sample.latitude == -33.89)
        #expect(sample.longitude == 151.19)
        #expect(sample.horizontalAccuracy == 10)
        #expect(sample.timestamp == Date(timeIntervalSince1970: 1_700_000_000))
    }

    @Test func knownSpeedIsCopied() {
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            altitude: 0,
            horizontalAccuracy: 10,
            verticalAccuracy: 10,
            course: 0,
            speed: 5,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let sample = LocationSample(location: location)
        #expect(sample.speed == 5)
    }
}
