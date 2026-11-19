import CoreLocation
import Foundation
import OSLog
import Observation
import UIKit

@Observable
@MainActor
final class LocationService: NSObject {
    private let manager = CLLocationManager()
    private var continuation: AsyncStream<LocationSample>.Continuation?

    let samples: AsyncStream<LocationSample>
    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var latestSample: LocationSample?
    private(set) var heading: Double?
    private var standardUpdatesActive = false

    override init() {
        var continuation: AsyncStream<LocationSample>.Continuation!
        self.samples = AsyncStream(bufferingPolicy: .bufferingNewest(16)) { continuation = $0 }
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        self.continuation = continuation
    }

    func start() {
        manager.delegate = self
        manager.requestAlwaysAuthorization()
        manager.startMonitoringSignificantLocationChanges()
        manager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        manager.distanceFilter = 20
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .fitness
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appBecameActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appEnteredBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        if UIApplication.shared.applicationState == .active {
            appBecameActive()
        }
    }

    private func refreshGeofence(using location: CLLocation) {
        guard manager.authorizationStatus == .authorizedAlways,
              CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self),
              let region = WalkingGeofence.region(
                  for: location,
                  replacing: manager.monitoredRegions.first { $0.identifier == WalkingGeofence.identifier },
                  maximumRadius: manager.maximumRegionMonitoringDistance
              ) else { return }
        manager.startMonitoring(for: region)
    }

    private func requestGeofenceLocation(for region: CLRegion) {
        guard region.identifier == WalkingGeofence.identifier else { return }
        manager.requestLocation()
    }

    @objc private func appBecameActive() {
        manager.startUpdatingLocation()
        standardUpdatesActive = true
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = 5
            manager.startUpdatingHeading()
        }
    }

    @objc private func appEnteredBackground() {
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        standardUpdatesActive = false
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        MainActor.assumeIsolated {
            let locationType: LocationType = standardUpdatesActive ? .foreground : .background
            for location in locations {
                let sample = LocationSample(location: location, locationType: locationType)
                latestSample = sample
                continuation?.yield(sample)
            }
            if let location = locations.max(by: { $0.timestamp < $1.timestamp }) {
                refreshGeofence(using: location)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        MainActor.assumeIsolated {
            requestGeofenceLocation(for: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        guard state == .outside else { return }
        MainActor.assumeIsolated {
            requestGeofenceLocation(for: region)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Logger().error("Geofence monitoring failed: \(error)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationStatus = status
            if status == .authorizedAlways {
                manager.requestLocation()
                for region in manager.monitoredRegions where region.identifier == WalkingGeofence.identifier {
                    manager.requestState(for: region)
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let heading: Double? = if newHeading.trueHeading >= 0 {
            newHeading.trueHeading
        } else if newHeading.magneticHeading >= 0 {
            newHeading.magneticHeading
        } else {
            nil
        }
        MainActor.assumeIsolated {
            self.heading = heading
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Logger().error("Location update failed: \(error)")
    }
}

enum WalkingGeofence {
    static let identifier = "walking-location"
    static let radius: CLLocationDistance = 100

    static func region(
        for location: CLLocation,
        replacing existing: CLRegion?,
        maximumRadius: CLLocationDistance,
        now: Date = Date()
    ) -> CLCircularRegion? {
        guard maximumRadius > 0,
              CLLocationCoordinate2DIsValid(location.coordinate),
              (0 ... VisitScorePolicy.maxHorizontalAccuracy).contains(location.horizontalAccuracy),
              abs(location.timestamp.timeIntervalSince(now)) <= 60 else { return nil }
        let effectiveRadius = min(radius, maximumRadius)
        if let existing = existing as? CLCircularRegion {
            let center = CLLocation(latitude: existing.center.latitude, longitude: existing.center.longitude)
            guard location.distance(from: center) >= effectiveRadius / 2 else { return nil }
        }
        let region = CLCircularRegion(center: location.coordinate, radius: effectiveRadius, identifier: identifier)
        region.notifyOnEntry = false
        region.notifyOnExit = true
        return region
    }
}
