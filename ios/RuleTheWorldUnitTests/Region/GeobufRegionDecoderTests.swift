import Foundation
import SwiftProtobuf
import Testing
@testable import RuleTheWorld

struct GeobufRegionDecoderTests {
    private func fixtureData() throws -> Data {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: root.appendingPathComponent("data/regions/geobuf-fixture.pbf"))
    }

    @Test func pythonEncodedFixturePreservesPrecisionPropertiesAndGeometry() throws {
        let regions = try GeobufRegionDecoder.decode(fixtureData())
        #expect(regions.map(\.id) == ["42", "43"])
        #expect(regions[0].name == "Île précise")
        #expect(regions[0].polygons[0].exterior.points[0] == .init(longitude: 1.000001, latitude: 1.000002))
        #expect(regions[0].polygons[0].exterior.points.count == 5)
        #expect(regions[1].parent == "42")
        #expect(regions[1].polygons.count == 2)
        #expect(regions[1].polygons[0].holes.count == 1)
        #expect(regions[1].contains(latitude: 1, longitude: 11))
        #expect(!regions[1].contains(latitude: 3, longitude: 13))
        #expect(regions[1].contains(latitude: 1, longitude: 31))
    }

    @Test func malformedWirePayloadsAreRejected() throws {
        let data = try fixtureData()
        #expect(throws: (any Error).self) { try GeobufRegionDecoder.decode(Data(data.dropLast())) }
        #expect(throws: (any Error).self) { try GeobufRegionDecoder.decode(Data([0x22, 0xff])) }
    }

    @Test(arguments: 0..<9)
    func malformedGeometryAndPropertiesAreRejected(variant: Int) throws {
        var message = try Geobuf_Data(serializedBytes: fixtureData())
        switch variant {
        case 0: message.dimensions = 3
        case 1: message.precision = 7
        case 2: message.featureCollection.features[0].properties[0] = UInt32.max
        case 3: message.featureCollection.features[0].properties[1] = UInt32.max
        case 4: message.featureCollection.features[0].geometry.lengths = [UInt32.max]
        case 5: message.featureCollection.features[0].geometry.coords.append(1)
        case 6: message.featureCollection.features[0].geometry.coords[0] = Int64.max
        case 7: message.featureCollection.features[0].geometry.type = .linestring
        default: message.featureCollection.features[0].properties.append(0)
        }
        let data = try message.serializedData()
        #expect(throws: RegionBoundaryError.self) { try GeobufRegionDecoder.decode(data) }
    }

    @Test func coordinateAdditionOverflowIsRejected() throws {
        var message = try Geobuf_Data(serializedBytes: fixtureData())
        message.featureCollection.features[0].geometry.coords[2] = Int64.max
        let data = try message.serializedData()
        #expect(throws: RegionBoundaryError.self) { try GeobufRegionDecoder.decode(data) }
    }

    @Test func unknownProtobufFieldsRemainForwardCompatible() throws {
        var data = try fixtureData()
        data.append(contentsOf: [0xa0, 0x06, 0x01])
        #expect(try GeobufRegionDecoder.decode(data).count == 2)
    }
}
