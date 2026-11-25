import Foundation
import SwiftyH3
import Testing
@testable import RuleTheWorld

private final class FakeSuburbShardStore: SuburbShardProviding, @unchecked Sendable {
    var index: RegionShardIndex?
    var shards: [String: Data] = [:]
    private(set) var indexLoads = 0
    private(set) var shardRequests: [String] = []

    func loadIndex() throws -> RegionShardIndex {
        indexLoads += 1
        guard let index else { throw RegionBoundaryError.missingResource }
        return index
    }

    func loadShard(cell: String) throws -> Data {
        shardRequests.append(cell)
        guard let data = shards[cell] else { throw RegionBoundaryError.missingResource }
        return data
    }
}

struct SuburbShardTests {
    private func feature(
        id: String, geometry: String, kind: String = "suburb", parent: String? = nil
    ) -> String {
        let parentProperty = parent.map { ",\"parent\":\"\($0)\"" } ?? ""
        return """
        {"type":"Feature","properties":{"id":"\(id)","name":"\(id)","kind":"\(kind)"\(parentProperty)},
        "geometry":{"type":"Polygon","coordinates":\(geometry)}}
        """
    }

    private func collection(_ features: [String]) throws -> Data {
        try RegionGeobufFixtures.encode(Data("""
        {"type":"FeatureCollection","features":[\(features.joined(separator: ","))]}
        """.utf8))
    }

    private func cellKey(latitude: Double, longitude: Double, resolution: Int32 = 4) throws -> String {
        let res = try #require(H3Cell.Resolution(rawValue: resolution))
        let cell = try H3LatLng(latitudeDegs: latitude, longitudeDegs: longitude).cell(at: res)
        return String(cell.id, radix: 16)
    }

    private func service(
        suburbJSON: String, at point: (latitude: Double, longitude: Double), store: FakeSuburbShardStore
    ) throws -> RegionBoundaryService {
        let cell = try cellKey(latitude: point.latitude, longitude: point.longitude)
        let shard = try collection([suburbJSON])
        store.index = RegionShardIndex(
            shardResolution: 4,
            shards: [cell: .init(features: 1, bytes: shard.count, sha256: "")],
            homes: ["nested": cell],
            coverage: [cell: ["nested"]]
        )
        store.shards = [cell: shard]
        let countries = try collection([
            feature(id: "land", geometry: "[[[0,0],[10,0],[10,10],[0,10],[0,0]]]", kind: "country")
        ])
        let states = try collection([
            feature(id: "child", geometry: "[[[0,0],[5,0],[5,10],[0,10],[0,0]]]", kind: "state", parent: "land")
        ])
        return RegionBoundaryService(
            data: [.medium: countries, .coarse: countries, .state: states], suburbStore: store
        )
    }

    @Test func suburbSelectionLoadsCoveringShardOnce() async throws {
        let store = FakeSuburbShardStore()
        let service = try service(
            suburbJSON: feature(
                id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", parent: "child"
            ),
            at: (latitude: 2, longitude: 1), store: store
        )
        let selection = try await service.selection(latitude: 2, longitude: 1, level: .suburb)
        #expect(selection?.boundary.id == "nested")
        #expect(selection?.level == .suburb)
        let cell = try cellKey(latitude: 2, longitude: 1)
        #expect(store.shardRequests == [cell])
        let again = try await service.selection(latitude: 2, longitude: 1, level: .suburb)
        #expect(again?.boundary.id == "nested")
        #expect(store.shardRequests == [cell])
        #expect(store.indexLoads == 1)
    }

    @Test func suburbSelectionFollowsCoverageToAnotherHomeCell() async throws {
        let store = FakeSuburbShardStore()
        let service = try service(
            suburbJSON: feature(
                id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", parent: "child"
            ),
            at: (latitude: 2, longitude: 1), store: store
        )
        let lookupCell = try cellKey(latitude: 2, longitude: 1)
        let homeCell = try cellKey(latitude: 20, longitude: 20)
        let shard = try collection([
            feature(id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", parent: "child")
        ])
        store.index = RegionShardIndex(
            shardResolution: 4,
            shards: [homeCell: .init(features: 1, bytes: shard.count, sha256: "")],
            homes: ["nested": homeCell],
            coverage: [lookupCell: ["nested"]]
        )
        store.shards = [homeCell: shard]
        let selection = try await service.selection(latitude: 2, longitude: 1, level: .suburb)
        #expect(selection?.boundary.id == "nested")
        #expect(store.shardRequests == [homeCell])
    }

    @Test func missingIndexAndUncoveredCellsYieldNilSuburbSelection() async throws {
        let store = FakeSuburbShardStore()
        let service = try service(
            suburbJSON: feature(
                id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", parent: "child"
            ),
            at: (latitude: 2, longitude: 1), store: store
        )
        store.index = nil
        #expect(try await service.selection(latitude: 2, longitude: 1, level: .suburb) == nil)
        store.index = RegionShardIndex(shardResolution: 4, shards: [:], homes: [:], coverage: [:])
        #expect(try await service.selection(latitude: 2, longitude: 1, level: .suburb) == nil)
        #expect(store.shardRequests.isEmpty)
    }

    @Test func suburbWithUnknownParentIsNotSelected() async throws {
        let store = FakeSuburbShardStore()
        let service = try service(
            suburbJSON: feature(
                id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", parent: "unknown"
            ),
            at: (latitude: 2, longitude: 1), store: store
        )
        #expect(try await service.selection(latitude: 2, longitude: 1, level: .suburb) == nil)
    }

    @Test func invalidPointsYieldNilSuburbSelection() async throws {
        let store = FakeSuburbShardStore()
        let service = try service(
            suburbJSON: feature(
                id: "nested", geometry: "[[[0,0],[2,0],[2,5],[0,5],[0,0]]]", parent: "child"
            ),
            at: (latitude: 2, longitude: 1), store: store
        )
        for (latitude, longitude) in [(Double.nan, 1.0), (91, 1.0), (2, .infinity)] {
            #expect(try await service.selection(latitude: latitude, longitude: longitude, level: .suburb) == nil)
        }
    }
}
