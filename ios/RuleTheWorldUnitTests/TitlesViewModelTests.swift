import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct TitlesViewModelTests {
    private func makeModel(session: FakeURLSession) -> TitlesViewModel {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("session-token")
        return TitlesViewModel(
            service: AuthenticatedService(tokenStore: tokens, urlSession: session),
            catalog: RankCatalog(data: Data(#"""
                {"country":[
                {"number":1,"name":"King","rarity":"legendary","femaleName":"Queen","description":"Sovereign"},
                {"number":15,"name":"Wanderer","rarity":"common","description":"Traveler"}]}
                """#.utf8)),
            regionNames: RegionNameCatalog(data: Data(#"{"1":"Zedland","2":"Arcadia","3":"Arcadia"}"#.utf8))
        )
    }

    private func makeModel(body: String) -> TitlesViewModel {
        makeModel(session: FakeURLSession { request in
            #expect(request.url?.path == "/api/me")
            return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200,
                                                   httpVersion: nil, headerFields: nil)!)
        })
    }

    @Test func resolvesTitlesSortsAndDeduplicatesByRegion() async {
        let model = makeModel(body: #"""
            {"rankings":[
            {"id":1,"type":"country","number":15},
            {"id":3,"type":"country","number":1},
            {"id":2,"type":"country","number":1},
            {"id":1,"type":"country","number":1},
            {"id":2,"type":"country","number":1}]}
            """#)
        await model.load()
        #expect(model.items.map(\.id) == ["country:2", "country:3", "country:1"])
        #expect(model.items.map(\.name) == ["King", "King", "King"])
        #expect(model.items.map(\.regionName) == ["Arcadia", "Arcadia", "Zedland"])
        #expect(model.items.first?.detail == "Sovereign")
        #expect(model.hasLoaded)
        #expect(!model.isLoading)
        #expect(model.message == nil)
    }

    @Test func highestRankSortsFirstAndUnknownAssignmentsRemainVisible() async {
        let model = makeModel(body: #"""
            {"rankings":[
            {"id":2,"type":"country","number":15},
            {"id":1,"type":"country","number":1},
            {"id":99,"type":"state","number":16},
            {"id":99,"type":"country","number":17}]}
            """#)
        await model.load()
        #expect(model.items.map(\.number) == [1, 15, 16, 17])
        #expect(model.items.map(\.rarity) == [.legendary, .common, nil, nil])
        #expect(model.items[2].name == "Title #16")
        #expect(model.items[2].regionName == "Region #99")
        #expect(model.items[2].detail == nil)
        #expect(model.items[3].id == "country:99")
    }

    @Test func emptyAwardsLoadSuccessfully() async {
        let model = makeModel(body: "{}")
        await model.load()
        #expect(model.items.isEmpty)
        #expect(model.hasLoaded)
        #expect(model.message == nil)
    }

    @Test func failureCanBeRetriedAndRefreshReplacesAwards() async {
        var status = 500
        var body = #"{"rankings":[{"id":1,"type":"country","number":1}]}"#
        let model = makeModel(session: FakeURLSession { request in
            (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status,
                                            httpVersion: nil, headerFields: nil)!)
        })
        await model.load()
        #expect(model.message != nil)
        #expect(!model.hasLoaded)
        #expect(!model.isLoading)
        status = 200
        await model.load()
        #expect(model.items.count == 1)
        #expect(model.message == nil)
        status = 500
        await model.load()
        #expect(model.items.count == 1)
        #expect(model.message != nil)
        status = 200
        body = "{}"
        await model.load()
        #expect(model.items.isEmpty)
        #expect(model.message == nil)
    }

    @Test func cancelledLoadDoesNotPublishResultsOrErrors() async {
        let model = makeModel(body: #"{"rankings":[{"id":1,"type":"country","number":1}]}"#)
        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            await model.load()
        }
        await task.value
        #expect(model.items.isEmpty)
        #expect(!model.hasLoaded)
        #expect(model.message == nil)
        #expect(!model.isLoading)
    }
}
