import Foundation
import Testing
@testable import RuleTheWorld

struct RegionTypeTests {
    @Test func rawValuesMatchServerSchema() {
        #expect(RegionType.none.rawValue == 0)
        #expect(RegionType.country.rawValue == 1)
        #expect(RegionType.state.rawValue == 2)
        #expect(RegionType.suburb.rawValue == 3)
    }

    @Test func codesAsInteger() throws {
        let encoded = try JSONEncoder().encode([RegionType.country, .state, .suburb])
        #expect(String(bytes: encoded, encoding: .utf8) == "[1,2,3]")
        #expect(try JSONDecoder().decode([RegionType].self, from: Data("[0,1,2,3]".utf8))
            == [.none, .country, .state, .suburb])
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(RegionType.self, from: Data("4".utf8)) }
    }

    @Test func namesRoundTrip() {
        for type in RegionType.allCases {
            #expect(RegionType(name: type.name) == type)
        }
        #expect(RegionType(name: "planet") == nil)
    }

    @Test func boundaryKindIsParsedAndUnknownKindsAreRejected() throws {
        func catalog(kind: String) throws -> RegionBoundaryCatalog {
            let data = Data("""
            {"type":"FeatureCollection","features":[{"type":"Feature",
            "properties":{"id":"a","name":"a","kind":"\(kind)"},
            "geometry":{"type":"Polygon","coordinates":[[[0,0],[2,0],[2,2],[0,2],[0,0]]]}}]}
            """.utf8)
            return try RegionBoundaryCatalog(data: [.medium: data, .coarse: data])
        }
        #expect(try catalog(kind: "state").boundaries[.medium]?.first?.kind == .state)
        #expect(try catalog(kind: "suburb").boundaries[.medium]?.first?.kind == .suburb)
        #expect(throws: RegionBoundaryError.self) { try catalog(kind: "planet") }
        #expect(throws: RegionBoundaryError.self) { try catalog(kind: "none") }
    }
}
