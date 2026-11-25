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
            profileService: ProfileService(
                service: AuthenticatedService(tokenStore: tokens, urlSession: session),
                store: ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())
            ),
            catalog: RankCatalog(data: Data(#"""
                {"global":[{"number":1,"name":"Emperor","rarity":"mythic","description":"World ruler","icon":"RankEmperor"}],"country":[
                {"number":1,"name":"King","rarity":"legendary","femaleName":"Queen","description":"Sovereign","stipend":100},
                {"number":15,"name":"Wanderer","rarity":"common","description":"Traveler"}]}
                """#.utf8)),
            regionNames: RegionNameCatalog(
                data: Data(#"{"1":"Zedland","2":"Arcadia","3":"Arcadia"}"#.utf8),
                demonymsData: Data(#"{"1":"Zedlandian","2":"Arcadian","3":"Arcadian"}"#.utf8)
            )
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
            {"id":3,"type":"country","number":1,"visited":40,"owned":12},
            {"id":2,"type":"country","number":1,"visited":9,"owned":3},
            {"id":1,"type":"country","number":1},
            {"id":2,"type":"country","number":1,"visited":9,"owned":3}]}
            """#)
        await model.load()
        #expect(model.items.map(\.id) == ["country:2", "country:3", "country:1"])
        #expect(model.items.map(\.name) == ["Arcadian King", "Arcadian King", "Zedlandian King"])
        #expect(model.items.map(\.regionName) == ["Arcadia", "Arcadia", "Zedland"])
        #expect(model.items.map(\.visited) == [9, 40, nil])
        #expect(model.items.map(\.owned) == [3, 12, nil])
        #expect(model.items.first?.detail == "Sovereign")
        #expect(model.items.first?.stipend == 100)
        #expect(model.items.last?.stipend == nil)
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

    @Test func globalTitleResolvesWorldNameAndIconWithoutCollidingWithCountry() async {
        let model = makeModel(body: #"""
            {"rankings":[
            {"id":1,"type":"global","number":1,"visited":12000,"owned":10000},
            {"id":1,"type":"country","number":1,"visited":2000,"owned":1000}]}
            """#)
        await model.load()
        #expect(model.items.count == 2)
        let global = model.items.first { $0.id == "global:1" }
        #expect(global?.name == "World Emperor")
        #expect(global?.regionName == "World")
        #expect(global?.icon == "RankEmperor")
        #expect(global?.rarity == .mythic)
        #expect(global?.owned == 10000)
        #expect(model.items.first { $0.id == "country:1" }?.regionName == "Zedland")
    }

    @Test func detailRetainsRegionalLadderAndAssignedRankRegardlessOfCounts() async {
        let model = makeModel(body: #"""
            {"rankings":[
            {"id":1,"type":"country","number":15,"visited":10000,"owned":5000},
            {"id":2,"type":"country","number":1,"visited":40,"owned":12},
            {"id":1,"type":"global","number":1,"visited":20000,"owned":10000},
            {"id":99,"type":"state","number":16},
            {"id":99,"type":"country","number":17}]}
            """#)
        await model.load()
        let country = model.items.first { $0.id == "country:1" }
        #expect(country?.type == "country")
        #expect(country?.regionName == "Zedland")
        #expect(country?.visited == 10000)
        #expect(country?.owned == 5000)
        #expect(country?.ranks.map(\.number) == [1, 15])
        #expect(country?.ranks.filter { $0.number == country?.number }.map(\.name) == ["Wanderer"])
        let global = model.items.first { $0.id == "global:1" }
        #expect(global?.regionName == "World")
        #expect(global?.ranks.map(\.name) == ["Emperor"])
        #expect(global?.visited == 20000)
        let state = model.items.first { $0.id == "state:99" }
        #expect(state?.ranks.isEmpty == true)
        #expect(state?.name == "Title #16")
        #expect(state?.visited == nil)
        #expect(state?.owned == nil)
        let unknown = model.items.first { $0.id == "country:99" }
        #expect(unknown?.ranks.map(\.number) == [1, 15])
        #expect(unknown?.number == 17)
        #expect(unknown?.name == "Title #17")
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
