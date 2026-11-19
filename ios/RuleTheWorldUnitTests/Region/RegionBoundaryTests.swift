import Foundation
import Testing
@testable import RuleTheWorld

struct RegionBoundaryTests {
    private func catalog(features: String) throws -> RegionBoundaryCatalog {
        let data = Data("""
        {"type":"FeatureCollection","features":[\(features)]}
        """.utf8)
        return try RegionBoundaryCatalog(data: [.medium: data, .coarse: data])
    }

    private func feature(id: String, geometry: String, type: String = "Polygon") -> String {
        """
        {"type":"Feature","properties":{"id":"\(id)","name":"\(id)","kind":"country"},
        "geometry":{"type":"\(type)","coordinates":\(geometry)}}
        """
    }

    @Test func holesAndEnclavesAreExcludedFromSurroundingCountry() throws {
        let outer = feature(
            id: "outer", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]],[[2,2],[4,2],[4,4],[2,4],[2,2]]]"
        )
        let inner = feature(id: "inner", geometry: "[[[2,2],[4,2],[4,4],[2,4],[2,2]]]")
        let catalog = try catalog(features: "\(outer),\(inner)")
        #expect(catalog.selection(latitude: 1, longitude: 1, level: .medium)?.boundary.id == "outer")
        #expect(catalog.selection(latitude: 3, longitude: 3, level: .medium)?.boundary.id == "inner")
        #expect(catalog.selection(latitude: 20, longitude: 20, level: .medium) == nil)
    }

    @Test func splitDatelineMultipolygonSupportsWrappedCoordinates() throws {
        let shape = feature(
            id: "islands",
            geometry: "[[[[178,0],[180,0],[180,2],[178,2],[178,0]]],[[[-180,0],[-178,0],[-178,2],[-180,2],[-180,0]]]]",
            type: "MultiPolygon"
        )
        let catalog = try catalog(features: shape)
        for longitude in [179.0, -179, 181, -181, 539, -539, 180, -180] {
            #expect(catalog.selection(latitude: 1, longitude: longitude, level: .medium)?.boundary.id == "islands")
        }
        #expect(catalog.selection(latitude: 1, longitude: 0, level: .medium) == nil)
        #expect(catalog.selection(latitude: .nan, longitude: 179, level: .medium) == nil)
        #expect(catalog.selection(latitude: 91, longitude: 179, level: .medium) == nil)
        #expect(catalog.selection(latitude: 1, longitude: .infinity, level: .medium) == nil)
    }

    @Test func sharedEdgesResolveByStableIdentityRatherThanFileOrder() throws {
        let left = feature(id: "a", geometry: "[[[0,0],[2,0],[2,2],[0,2],[0,0]]]")
        let right = feature(id: "b", geometry: "[[[2,0],[4,0],[4,2],[2,2],[2,0]]]")
        for features in ["\(left),\(right)", "\(right),\(left)"] {
            let catalog = try catalog(features: features)
            #expect(catalog.selection(latitude: 1, longitude: 2, level: .medium)?.boundary.id == "a")
        }
    }

    @Test func coarseDisplayStillUsesMediumGeometryForSelection() throws {
        let medium = feature(id: "country", geometry: "[[[0,0],[4,0],[4,4],[0,4],[0,0]]]")
        let coarse = feature(id: "country", geometry: "[[[0,0],[2,0],[2,2],[0,2],[0,0]]]")
        let catalog = try RegionBoundaryCatalog(data: [
            .medium: Data("{\"type\":\"FeatureCollection\",\"features\":[\(medium)]}".utf8),
            .coarse: Data("{\"type\":\"FeatureCollection\",\"features\":[\(coarse)]}".utf8),
        ])
        let selected = catalog.selection(latitude: 3, longitude: 3, level: .coarse)
        #expect(selected?.boundary.id == "country")
        #expect(selected?.level == .coarse)
        #expect(selected?.boundary.contains(latitude: 3, longitude: 3) == false)
    }

    @Test func malformedRingsAndDuplicateIdentitiesAreRejected() {
        let unclosed = feature(id: "bad", geometry: "[[[0,0],[2,0],[2,2],[0,2]]]")
        #expect(throws: RegionBoundaryError.self) { try catalog(features: unclosed) }
        let crossing = feature(id: "bad", geometry: "[[[179,0],[-179,0],[-179,2],[179,0]]]")
        #expect(throws: RegionBoundaryError.self) { try catalog(features: crossing) }
        let valid = feature(id: "same", geometry: "[[[0,0],[2,0],[2,2],[0,0]]]")
        #expect(throws: RegionBoundaryError.self) { try catalog(features: "\(valid),\(valid)") }
    }

    @Test func bundledCountriesDecodeAndSelectConsistentlyAcrossLevels() async throws {
        let service = RegionBoundaryService(bundle: Bundle(for: HexMapViewModel.self))
        let locations: [String: MapRegionBoundary.Point] = [
            "Australia": .init(longitude: 134, latitude: -25),
            "France": .init(longitude: 2.35, latitude: 48.85),
            "Switzerland": .init(longitude: 8.2, latitude: 46.8),
            "Fiji": .init(longitude: 178, latitude: -17.8),
        ]
        for (name, point) in locations {
            let medium = try await service.selection(
                latitude: point.latitude, longitude: point.longitude, level: .medium
            )
            let coarse = try await service.selection(
                latitude: point.latitude, longitude: point.longitude, level: .coarse
            )
            #expect(medium?.boundary.name == name)
            #expect(medium?.boundary.id == coarse?.boundary.id)
            #expect(coarse?.level == .coarse)
        }
        let fijiAcrossDateline = try await service.selection(latitude: -16.8, longitude: -179.9, level: .medium)
        #expect(fijiAcrossDateline?.boundary.name == "Fiji")
        let ocean = try await service.selection(latitude: 0, longitude: -140, level: .medium)
        #expect(ocean == nil)
    }
}
