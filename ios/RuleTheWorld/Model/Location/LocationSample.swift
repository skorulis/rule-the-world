import CoreLocation
import Foundation

struct LocationSample: Sendable, Equatable {
    let latitude: Double
    let longitude: Double
    let speed: Double?
    let course: Double?
    let horizontalAccuracy: Double
    let timestamp: Date
    let locationType: LocationType

    nonisolated var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    nonisolated init(
        latitude: Double,
        longitude: Double,
        speed: Double?,
        course: Double?,
        horizontalAccuracy: Double,
        timestamp: Date,
        locationType: LocationType = .foreground
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
        self.locationType = locationType
    }

    nonisolated init(location: CLLocation, locationType: LocationType = .foreground) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
        self.speed = location.speed >= 0 ? location.speed : nil
        self.course = location.course >= 0 ? location.course : nil
        self.horizontalAccuracy = location.horizontalAccuracy
        self.timestamp = location.timestamp
        self.locationType = locationType
    }
}
