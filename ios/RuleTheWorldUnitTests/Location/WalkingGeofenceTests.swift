import CoreLocation
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct WalkingGeofenceTests {
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    private func location(latitude: Double = -33.89, accuracy: Double = 10, age: TimeInterval = 0) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: 151.19),
            altitude: 0,
            horizontalAccuracy: accuracy,
            verticalAccuracy: 10,
            timestamp: now.addingTimeInterval(-age)
        )
    }

    @Test func createsExitOnlyFenceAroundFreshLocation() throws {
        let fix = location()
        let region = try #require(WalkingGeofence.region(for: fix, replacing: nil, maximumRadius: 1000, now: now))
        #expect(region.identifier == WalkingGeofence.identifier)
        #expect(region.radius == 100)
        #expect(region.center.latitude == fix.coordinate.latitude)
        #expect(region.center.longitude == fix.coordinate.longitude)
        #expect(!region.notifyOnEntry)
        #expect(region.notifyOnExit)
    }

    @Test func rejectsStaleAndInaccurateLocations() {
        for fix in [location(age: 61), location(accuracy: -1), location(accuracy: 101)] {
            #expect(WalkingGeofence.region(for: fix, replacing: nil, maximumRadius: 1000, now: now) == nil)
        }
    }

    @Test func avoidsRecenteringForSmallMovements() throws {
        let region = try #require(WalkingGeofence.region(for: location(), replacing: nil, maximumRadius: 1000, now: now))
        #expect(WalkingGeofence.region(for: location(latitude: -33.8899), replacing: region, maximumRadius: 1000, now: now) == nil)
        let moved = try #require(WalkingGeofence.region(
            for: location(latitude: -33.889), replacing: region, maximumRadius: 1000, now: now
        ))
        #expect(moved.center.latitude == -33.889)
        #expect(moved.identifier == region.identifier)
    }

    @Test func respectsDeviceMaximumRadius() throws {
        let region = try #require(WalkingGeofence.region(for: location(), replacing: nil, maximumRadius: 75, now: now))
        #expect(region.radius == 75)
        #expect(WalkingGeofence.region(for: location(), replacing: nil, maximumRadius: 0, now: now) == nil)
    }
}
