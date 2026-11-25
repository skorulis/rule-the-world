import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct RegionDetailViewModelTests {
    private let country = MapRegionBoundary(id: "7", name: "Zedland", kind: .country, polygons: [])
    private let suburb = MapRegionBoundary(id: "9", name: "Burrow", kind: .suburb, polygons: [])
    private let state = MapRegionBoundary(id: "5", name: "Province", kind: .state, polygons: [])

    private let catalog = RankCatalog(data: Data(#"""
        {"country":[{"number":1,"name":"King","description":"Sovereign"}],
         "suburb":[{"number":1,"name":"Mayor","description":"Local ruler"}]}
        """#.utf8))

    @Test func loadsLeadersForRankedRegionTypes() async {
        let provider = StubLeadersProvider(leaders: [
            RegionLeader(rank: 1, name: "Alice"),
            RegionLeader(rank: 3, name: "Bob"),
        ])
        let model = RegionDetailViewModel(region: country, leadersProvider: provider, catalog: catalog)
        await model.load()
        #expect(model.leaders?.map(\.name) == ["Alice", "Bob"])
        #expect(model.message == nil)
        #expect(!model.isLoading)
        #expect(provider.requests == [.init(type: .country, id: 7)])
        #expect(model.rankName(for: RegionLeader(rank: 1, name: "Alice")) == "King")
        #expect(model.rankName(for: RegionLeader(rank: 2, name: "Eve")) == "Rank #2")
    }

    @Test func skipsFetchForStateRegions() async {
        let provider = StubLeadersProvider(leaders: [RegionLeader(rank: 1, name: "Alice")])
        let model = RegionDetailViewModel(region: state, leadersProvider: provider, catalog: catalog)
        await model.load()
        #expect(model.leaders == [])
        #expect(model.message == nil)
        #expect(provider.requests.isEmpty)
    }

    @Test func skipsFetchForUnparseableRegionIds() async {
        let provider = StubLeadersProvider(leaders: [])
        let region = MapRegionBoundary(id: "land", name: "Land", kind: .country, polygons: [])
        let model = RegionDetailViewModel(region: region, leadersProvider: provider, catalog: catalog)
        await model.load()
        #expect(model.leaders == [])
        #expect(provider.requests.isEmpty)
    }

    @Test func surfacesFailuresAsRetryableMessages() async {
        let provider = StubLeadersProvider(error: URLError(.timedOut))
        let model = RegionDetailViewModel(region: suburb, leadersProvider: provider, catalog: catalog)
        await model.load()
        #expect(model.leaders == nil)
        #expect(model.message != nil)
        provider.error = nil
        provider.leaders = [RegionLeader(rank: 1, name: "Carol")]
        await model.load()
        #expect(model.leaders?.map(\.name) == ["Carol"])
        #expect(model.message == nil)
        #expect(provider.requests == [.init(type: .suburb, id: 9), .init(type: .suburb, id: 9)])
    }
}

private final class StubLeadersProvider: RegionLeadersProviding, @unchecked Sendable {
    struct Request: Equatable, Sendable {
        let type: RegionType
        let id: Int64
    }

    var leaders: [RegionLeader]
    var error: Error?
    private(set) var requests: [Request] = []

    init(leaders: [RegionLeader] = [], error: Error? = nil) {
        self.leaders = leaders
        self.error = error
    }

    func regionLeaders(type: RegionType, id: Int64) async throws -> [RegionLeader] {
        requests.append(Request(type: type, id: id))
        if let error { throw error }
        return leaders
    }
}
