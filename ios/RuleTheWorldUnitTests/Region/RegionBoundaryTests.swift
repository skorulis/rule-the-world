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

    private func feature(
        id: String, geometry: String, type: String = "Polygon", kind: String = "country", parent: String? = nil
    ) -> String {
        let parentProperty = parent.map { ",\"parent\":\"\($0)\"" } ?? ""
        return """
        {"type":"Feature","properties":{"id":"\(id)","name":"\(id)","kind":"\(kind)"\(parentProperty)},
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

    @Test func stateSelectionIsScopedToTheContainingCountry() throws {
        let countries = feature(id: "land", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]]]")
        let states = feature(
            id: "child", geometry: "[[[0,0],[5,0],[5,10],[0,10],[0,0]]]", kind: "state", parent: "land"
        )
        let countryData = Data("""
        {"type":"FeatureCollection","features":[\(countries)]}
        """.utf8)
        let stateData = Data("""
        {"type":"FeatureCollection","features":[\(states)]}
        """.utf8)
        let catalog = try RegionBoundaryCatalog(data: [.medium: countryData, .coarse: countryData, .state: stateData])
        #expect(catalog.selection(latitude: 5, longitude: 2, level: .state)?.boundary.id == "child")
        #expect(catalog.selection(latitude: 5, longitude: 7, level: .state) == nil)
        #expect(catalog.selection(latitude: 5, longitude: 2, level: .medium)?.boundary.id == "land")
        #expect(catalog.selection(latitude: 20, longitude: 20, level: .state) == nil)
    }

    @Test func suburbSelectionIsScopedToTheContainingState() throws {
        let countries = feature(id: "land", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]]]")
        let states = feature(
            id: "child", geometry: "[[[0,0],[5,0],[5,10],[0,10],[0,0]]]", kind: "state", parent: "land"
        )
        let suburbs = feature(
            id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", kind: "suburb", parent: "child"
        )
        let countryData = Data("""
        {"type":"FeatureCollection","features":[\(countries)]}
        """.utf8)
        let stateData = Data("""
        {"type":"FeatureCollection","features":[\(states)]}
        """.utf8)
        let suburbData = Data("""
        {"type":"FeatureCollection","features":[\(suburbs)]}
        """.utf8)
        let catalog = try RegionBoundaryCatalog(data: [
            .medium: countryData, .coarse: countryData, .state: stateData, .suburb: suburbData,
        ])
        #expect(catalog.selection(latitude: 2, longitude: 1, level: .suburb)?.boundary.id == "nested")
        #expect(catalog.selection(latitude: 2, longitude: 3, level: .suburb) == nil)
        #expect(catalog.selection(latitude: 2, longitude: 1, level: .state)?.boundary.id == "child")
        #expect(catalog.selection(latitude: 5, longitude: 7, level: .suburb) == nil)
        #expect(catalog.selection(latitude: 20, longitude: 20, level: .suburb) == nil)
    }

    @Test func detailedSuburbSelectionDoesNotRequireCoarseParentContainment() throws {
        let country = feature(id: "land", geometry: "[[[0,0],[2,0],[2,4],[0,4],[0,0]]]")
        let state = feature(
            id: "state", geometry: "[[[0,0],[1,0],[1,4],[0,4],[0,0]]]", kind: "state", parent: "land"
        )
        let suburb = feature(
            id: "suburb", geometry: "[[[0,0],[4,0],[4,4],[0,4],[0,0]]]", kind: "suburb", parent: "state"
        )
        func collection(_ feature: String) -> Data {
            Data("{\"type\":\"FeatureCollection\",\"features\":[\(feature)]}".utf8)
        }
        let catalog = try RegionBoundaryCatalog(data: [
            .medium: collection(country), .coarse: collection(country),
            .state: collection(state), .suburb: collection(suburb),
        ])
        #expect(catalog.selection(latitude: 2, longitude: 3, level: .suburb)?.boundary.id == "suburb")
        #expect(catalog.selection(latitude: 2, longitude: 3, level: .medium) == nil)
        #expect(catalog.selection(latitude: 2, longitude: 3, level: .state) == nil)
    }

    @Test func suburbsWithUnknownParentsAreRejected() {
        let country = feature(id: "land", geometry: "[[[0,0],[4,0],[4,4],[0,4],[0,0]]]")
        let suburb = feature(
            id: "suburb", geometry: "[[[0,0],[4,0],[4,4],[0,4],[0,0]]]", kind: "suburb", parent: "unknown"
        )
        let countryData = Data("{\"type\":\"FeatureCollection\",\"features\":[\(country)]}".utf8)
        let suburbData = Data("{\"type\":\"FeatureCollection\",\"features\":[\(suburb)]}".utf8)
        #expect(throws: RegionBoundaryError.self) {
            try RegionBoundaryCatalog(data: [.medium: countryData, .coarse: countryData, .suburb: suburbData])
        }
    }

    @Test func suburbCollectionsRequireParents() {
        let countries = feature(id: "land", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]]]")
        let orphan = feature(id: "child", geometry: "[[[0,0],[5,0],[5,10],[0,10],[0,0]]]", kind: "suburb")
        let countryData = Data("""
        {"type":"FeatureCollection","features":[\(countries)]}
        """.utf8)
        let suburbData = Data("""
        {"type":"FeatureCollection","features":[\(orphan)]}
        """.utf8)
        #expect(throws: RegionBoundaryError.self) {
            try RegionBoundaryCatalog(data: [.medium: countryData, .coarse: countryData, .suburb: suburbData])
        }
    }

    @Test func missingSuburbCollectionIsTolerated() throws {
        let countries = feature(id: "land", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]]]")
        let countryData = Data("""
        {"type":"FeatureCollection","features":[\(countries)]}
        """.utf8)
        let catalog = try RegionBoundaryCatalog(data: [.medium: countryData, .coarse: countryData])
        #expect(catalog.selection(latitude: 5, longitude: 5, level: .suburb) == nil)
    }

    @Test func stateCollectionsRequireParents() {
        let countries = feature(id: "land", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]]]")
        let orphan = feature(id: "child", geometry: "[[[0,0],[5,0],[5,10],[0,10],[0,0]]]", kind: "state")
        let countryData = Data("""
        {"type":"FeatureCollection","features":[\(countries)]}
        """.utf8)
        let stateData = Data("""
        {"type":"FeatureCollection","features":[\(orphan)]}
        """.utf8)
        #expect(throws: RegionBoundaryError.self) {
            try RegionBoundaryCatalog(data: [.medium: countryData, .coarse: countryData, .state: stateData])
        }
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

    @Test func bundledSuburbsRetainSourceCoastalDetail() async throws {
        struct Point: Decodable {
            let latitude: Double
            let longitude: Double
            let name: String
            let id: String
        }
        struct Source: Decodable {
            let regressionPoints: [Point]
        }
        let bundle = Bundle(for: HexMapViewModel.self)
        let url = try #require(
            bundle.url(forResource: "suburbs-source", withExtension: "json")
                ?? bundle.url(forResource: "suburbs-source", withExtension: "json", subdirectory: "Regions")
        )
        let source = try JSONDecoder().decode(Source.self, from: Data(contentsOf: url))
        #expect(!source.regressionPoints.isEmpty)
        let service = RegionBoundaryService(bundle: bundle)
        for point in source.regressionPoints {
            let selection = try await service.selection(
                latitude: point.latitude, longitude: point.longitude, level: .suburb
            )
            #expect(selection?.boundary.id == point.id)
            #expect(selection?.boundary.name == point.name)
        }
    }

    @Test func bundledStatesSelectWithinTheirParentCountry() async throws {
        let service = RegionBoundaryService(bundle: Bundle(for: HexMapViewModel.self))
        let sydney = try await service.selection(latitude: -33.8, longitude: 151.2, level: .state)
        #expect(sydney?.boundary.name == "New South Wales")
        #expect(sydney?.boundary.kind == .state)
        #expect(sydney?.boundary.parent != nil)
        let paris = try await service.selection(latitude: 48.85, longitude: 2.35, level: .state)
        #expect(paris == nil)
        let ocean = try await service.selection(latitude: 0, longitude: -140, level: .state)
        #expect(ocean == nil)
    }
}
