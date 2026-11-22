import Foundation
import SwiftProtobuf

nonisolated enum GeobufRegionDecoder {
    static func decode(_ data: Data) throws -> [MapRegionBoundary] {
        let message = try Geobuf_Data(serializedBytes: data)
        guard message.dimensions == 2, message.precision <= 6,
              case .featureCollection(let collection)? = message.dataType,
              !collection.features.isEmpty else {
            throw RegionBoundaryError.invalidCollection
        }
        let scale = pow(10.0, Double(message.precision))
        return try collection.features.map { feature in
            let properties = try decodeProperties(feature, keys: message.keys)
            guard let id = properties["id"], !id.isEmpty, let name = properties["name"],
                  let kindName = properties["kind"], let kind = RegionType(name: kindName), kind != .none,
                  feature.hasGeometry else {
                throw RegionBoundaryError.invalidCollection
            }
            return try MapRegionBoundary(
                id: id, name: name, kind: kind, parent: properties["parent"],
                polygons: polygons(feature.geometry, scale: scale)
            )
        }
    }

    private static func decodeProperties(_ feature: Geobuf_Data.Feature, keys: [String]) throws -> [String: String] {
        guard feature.properties.count.isMultiple(of: 2) else { throw RegionBoundaryError.invalidCollection }
        var result: [String: String] = [:]
        for index in stride(from: 0, to: feature.properties.count, by: 2) {
            let key = Int(feature.properties[index])
            let value = Int(feature.properties[index + 1])
            guard keys.indices.contains(key), feature.values.indices.contains(value),
                  case .stringValue(let string)? = feature.values[value].valueType,
                  result.updateValue(string, forKey: keys[key]) == nil else {
                throw RegionBoundaryError.invalidCollection
            }
        }
        return result
    }

    private static func polygons(
        _ geometry: Geobuf_Data.Geometry, scale: Double
    ) throws -> [MapRegionBoundary.Polygon] {
        guard geometry.hasType, geometry.type == .polygon || geometry.type == .multipolygon,
              !geometry.coords.isEmpty, geometry.coords.count.isMultiple(of: 2) else {
            throw RegionBoundaryError.invalidGeometry
        }
        var lengths = geometry.lengths.makeIterator()
        var coordinates = Coordinates(deltas: geometry.coords, scale: scale)
        func nextLength() throws -> Int {
            guard let length = lengths.next(), length > 0 else { throw RegionBoundaryError.invalidGeometry }
            return Int(length)
        }
        let implicit = geometry.lengths.isEmpty
        let polygonCount = geometry.type == .multipolygon && !implicit ? try nextLength() : 1
        guard polygonCount <= coordinates.remaining / 3 else { throw RegionBoundaryError.invalidGeometry }
        var result: [MapRegionBoundary.Polygon] = []
        for _ in 0..<polygonCount {
            let ringCount = implicit ? 1 : geometry.type == .polygon ? geometry.lengths.count : try nextLength()
            guard ringCount > 0, ringCount <= coordinates.remaining / 3 else {
                throw RegionBoundaryError.invalidGeometry
            }
            var rings: [MapRegionBoundary.Ring] = []
            for _ in 0..<ringCount {
                let count = implicit ? coordinates.remaining : try nextLength()
                rings.append(try coordinates.ring(count: count))
            }
            guard let exterior = rings.first else { throw RegionBoundaryError.invalidGeometry }
            result.append(MapRegionBoundary.Polygon(exterior: exterior, holes: Array(rings.dropFirst())))
        }
        guard coordinates.remaining == 0, lengths.next() == nil else {
            throw RegionBoundaryError.invalidGeometry
        }
        return result
    }

    private struct Coordinates: Sendable {
        let deltas: [Int64]
        let scale: Double
        var index = 0
        var remaining: Int { (deltas.count - index) / 2 }

        mutating func ring(count: Int) throws -> MapRegionBoundary.Ring {
            guard count >= 3, count <= remaining else { throw RegionBoundaryError.invalidGeometry }
            var longitude: Int64 = 0
            var latitude: Int64 = 0
            var points: [MapRegionBoundary.Point] = []
            points.reserveCapacity(count + 1)
            for _ in 0..<count {
                let (long, xOverflow) = longitude.addingReportingOverflow(deltas[index])
                let (lat, yOverflow) = latitude.addingReportingOverflow(deltas[index + 1])
                index += 2
                guard !xOverflow, !yOverflow else { throw RegionBoundaryError.invalidGeometry }
                longitude = long
                latitude = lat
                let point = MapRegionBoundary.Point(longitude: Double(long) / scale, latitude: Double(lat) / scale)
                guard (-180...180).contains(point.longitude), (-90...90).contains(point.latitude) else {
                    throw RegionBoundaryError.invalidGeometry
                }
                points.append(point)
            }
            guard let first = points.first else { throw RegionBoundaryError.invalidGeometry }
            points.append(first)
            return try MapRegionBoundary.Ring(points: points)
        }
    }
}
