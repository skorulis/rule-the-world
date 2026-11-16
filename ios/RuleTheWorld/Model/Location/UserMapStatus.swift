import Foundation

struct UserMapStatus: Equatable, Sendable {
    var latitude: Double
    var longitude: Double
    var directionDegrees: Double?
    var speedKmh: Double?

    nonisolated static func == (lhs: UserMapStatus, rhs: UserMapStatus) -> Bool {
        lhs.latitude == rhs.latitude
            && lhs.longitude == rhs.longitude
            && lhs.directionDegrees == rhs.directionDegrees
            && lhs.speedKmh == rhs.speedKmh
    }

    nonisolated static func make(sample: LocationSample?, heading: Double?) -> UserMapStatus? {
        guard let sample else { return nil }
        let speedKmh = sample.speed.map { $0 * 3.6 }.flatMap { $0 > 0 ? $0 : nil }
        return UserMapStatus(
            latitude: sample.latitude,
            longitude: sample.longitude,
            directionDegrees: heading,
            speedKmh: speedKmh
        )
    }
}
