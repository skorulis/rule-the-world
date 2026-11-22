import Foundation
import SwiftProtobuf
@testable import RuleTheWorld

extension RegionBoundaryCatalog {
    init(fixtures: [RegionOverlayPolicy.Level: Data]) throws {
        try self.init(data: fixtures.mapValues { try RegionGeobufFixtures.encode($0) })
    }
}

nonisolated enum RegionGeobufFixtures {
    static func encode(_ json: Data) throws -> Data {
        let collection = try JSONDecoder().decode(Collection.self, from: json)
        var message = Geobuf_Data()
        message.keys = ["id", "name", "kind", "parent"]
        message.featureCollection.features = try collection.features.map { input in
            var feature = Geobuf_Data.Feature()
            for (key, value) in [input.properties.id, input.properties.name, input.properties.kind, input.properties.parent].enumerated() {
                if let value {
                    var property = Geobuf_Data.Value()
                    property.stringValue = value
                    feature.properties += [UInt32(key), UInt32(feature.values.count)]
                    feature.values.append(property)
                }
            }
            let polygons = input.geometry.polygons
            var geometry = Geobuf_Data.Geometry()
            geometry.type = .multipolygon
            geometry.lengths = [UInt32(polygons.count)]
            for polygon in polygons {
                geometry.lengths.append(UInt32(polygon.count))
                for ring in polygon {
                    guard !ring.isEmpty else { throw RegionBoundaryError.invalidGeometry }
                    geometry.lengths.append(UInt32(ring.count - 1))
                    var previous: [Int64] = [0, 0]
                    for point in ring.dropLast() {
                        for dimension in 0..<2 {
                            let value = Int64((point[dimension] * 1_000_000).rounded())
                            geometry.coords.append(value - previous[dimension])
                            previous[dimension] = value
                        }
                    }
                }
            }
            feature.geometry = geometry
            return feature
        }
        return try message.serializedData()
    }

    private struct Collection: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let properties: Properties
        let geometry: Geometry
    }

    private struct Properties: Decodable {
        let id: String
        let name: String
        let kind: String
        let parent: String?
    }

    private enum GeometryKeys: CodingKey {
        case type, coordinates
    }

    private struct Geometry: Decodable {
        let polygons: [[[[Double]]]]

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: GeometryKeys.self)
            if try container.decode(String.self, forKey: .type) == "Polygon" {
                polygons = [try container.decode([[[Double]]].self, forKey: .coordinates)]
            } else {
                polygons = try container.decode([[[[Double]]]].self, forKey: .coordinates)
            }
        }
    }
}
