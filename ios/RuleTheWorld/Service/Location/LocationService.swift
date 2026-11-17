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
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        MainActor.assumeIsolated {
            authorizationStatus = status
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
