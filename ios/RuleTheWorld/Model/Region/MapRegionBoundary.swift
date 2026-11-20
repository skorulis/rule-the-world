import Foundation

nonisolated struct MapRegionBoundary: Sendable, Identifiable {
    struct Point: Decodable, Sendable, Equatable {
        let longitude: Double
        let latitude: Double

        init(longitude: Double, latitude: Double) {
            self.longitude = longitude
            self.latitude = latitude
        }

        init(from decoder: any Decoder) throws {
            var values = try decoder.unkeyedContainer()
            longitude = try values.decode(Double.self)
            latitude = try values.decode(Double.self)
            guard longitude.isFinite, latitude.isFinite,
                  (-180...180).contains(longitude), (-90...90).contains(latitude) else {
                throw RegionBoundaryError.invalidGeometry
            }
        }
    }

    struct Ring: Sendable {
        let points: [Point]
        let minLongitude: Double
        let maxLongitude: Double
        let minLatitude: Double
        let maxLatitude: Double

        init(points: [Point]) throws {
            guard points.count >= 4, points.first == points.last,
                  zip(points, points.dropFirst()).allSatisfy({ abs($0.longitude - $1.longitude) <= 180 }) else {
                throw RegionBoundaryError.invalidGeometry
            }
            self.points = points
            minLongitude = points.map(\.longitude).min()!
            maxLongitude = points.map(\.longitude).max()!
            minLatitude = points.map(\.latitude).min()!
            maxLatitude = points.map(\.latitude).max()!
        }

        func contains(_ point: Point) -> Bool {
            guard (minLongitude...maxLongitude).contains(point.longitude),
                  (minLatitude...maxLatitude).contains(point.latitude) else { return false }
            var inside = false
            for (start, end) in zip(points, points.dropFirst()) {
                let dx = end.longitude - start.longitude
                let dy = end.latitude - start.latitude
                let cross = (point.longitude - start.longitude) * dy - (point.latitude - start.latitude) * dx
                let longitudeRange = min(start.longitude, end.longitude)...max(start.longitude, end.longitude)
                let latitudeRange = min(start.latitude, end.latitude)...max(start.latitude, end.latitude)
                if abs(cross) <= 1e-10,
                   longitudeRange.contains(point.longitude), latitudeRange.contains(point.latitude) {
                    return true
                }
                if (start.latitude > point.latitude) != (end.latitude > point.latitude) {
                    let intersection = start.longitude + (point.latitude - start.latitude) * dx / dy
                    if point.longitude < intersection {
                        inside.toggle()
                    }
                }
            }
            return inside
        }
    }

    struct Polygon: Sendable {
        let exterior: Ring
        let holes: [Ring]

        func contains(_ point: Point) -> Bool {
            exterior.contains(point) && !holes.contains { $0.contains(point) }
        }
    }

    let id: String
    let name: String
    let kind: RegionType
    let parent: String?
    let polygons: [Polygon]

    init(id: String, name: String, kind: RegionType, parent: String? = nil, polygons: [Polygon]) {
        self.id = id
        self.name = name
        self.kind = kind
        self.parent = parent
        self.polygons = polygons
    }

    func contains(latitude: Double, longitude: Double) -> Bool {
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude) else { return false }
        let wrapped = ((longitude + 180).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) - 180
        let point = Point(longitude: wrapped, latitude: latitude)
        return polygons.contains { polygon in
            polygon.contains(point) || (wrapped == -180 && polygon.contains(Point(longitude: 180, latitude: latitude)))
        }
    }
}

nonisolated enum RegionBoundaryError: Error {
    case invalidGeometry
    case invalidCollection
    case missingResource
}

nonisolated struct MapRegionSelection: Sendable, Equatable {
    let boundary: MapRegionBoundary
    let level: RegionOverlayPolicy.Level

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.boundary.id == rhs.boundary.id && lhs.level == rhs.level
    }
}
