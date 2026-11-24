import Foundation
import Testing
@testable import RuleTheWorld

struct RankCatalogTests {
    @Test func resolvesDefaultNamesByTypeAndKeepsFirstDuplicate() {
        let catalog = RankCatalog(data: Data(#"""
            {"country":[
            {"number":1,"name":"King","rarity":"mythic","femaleName":"Queen","description":"Sovereign"},
            {"number":1,"name":"Duplicate","rarity":"common","description":"Ignored"}],
            "state":[{"number":1,"name":"Governor","rarity":"epic","description":"State ruler"}]}
            """#.utf8))
        #expect(catalog.definition(for: 1, type: "country")?.name == "King")
        #expect(catalog.definition(for: 1, type: "country")?.description == "Sovereign")
        #expect(catalog.definition(for: 1, type: "country")?.rarity == .mythic)
        #expect(catalog.definition(for: 1, type: "state")?.name == "Governor")
        #expect(catalog.definition(for: 99, type: "country") == nil)
        #expect(catalog.definition(for: 1, type: "suburb") == nil)
    }

    @Test func listsRanksHighestFirstWithRequirementsAndTypeIsolation() {
        let catalog = RankCatalog(data: Data(#"""
            {"country":[
            {"number":15,"name":"Wanderer","rarity":"common","description":"Traveler","minOwnership":0,"minVisits":1},
            {"number":1,"name":"King","rarity":"mythic","description":"Sovereign","minOwnership":1000,"minVisits":20,"maxQuantity":1},
            {"number":1,"name":"Duplicate","rarity":"common","description":"Ignored"},
            {"number":5,"name":"Count","rarity":"epic","description":"Noble","minOwnership":1000,"minVisits":15,"maxPercentage":1.5},
            {"number":0,"name":"Invalid","rarity":"common","description":"Ignored"}],
            "global":[{"number":1,"name":"Emperor","rarity":"mythic","description":"World ruler"}]}
            """#.utf8))
        let ranks = catalog.definitions(for: "country")
        #expect(ranks.map(\.number) == [1, 5, 15])
        #expect(ranks.map(\.name) == ["King", "Count", "Wanderer"])
        #expect(ranks[0].minOwnership == 1000)
        #expect(ranks[0].minVisits == 20)
        #expect(ranks[0].maxQuantity == 1)
        #expect(ranks[0].maxPercentage == nil)
        #expect(ranks[1].maxPercentage == 1.5)
        #expect(ranks[1].maxQuantity == nil)
        #expect(ranks[2].minOwnership == 0)
        #expect(catalog.definitions(for: "state").isEmpty)
        let global = catalog.definitions(for: "global")
        #expect(global.map(\.name) == ["Emperor"])
        #expect(global.first?.minOwnership == nil)
        #expect(global.first?.minVisits == nil)
    }

    @Test func missingOrInvalidDataHasNoDefinitions() {
        for data in [nil, Data("invalid".utf8), Data("{}".utf8)] {
            #expect(RankCatalog(data: data).definition(for: 1, type: "country") == nil)
        }
    }

    @Test @MainActor func bundledCatalogContainsCountryTitles() {
        let catalog = RankCatalog(bundle: Bundle(for: ProfileViewModel.self))
        #expect(catalog.definition(for: 1, type: "country")?.name == "King")
        #expect(catalog.definition(for: 15, type: "country")?.name == "Wanderer")
        #expect(catalog.definition(for: 1, type: "country")?.rarity == .mythic)
        #expect(catalog.definition(for: 15, type: "country")?.rarity == .common)
        #expect(catalog.definition(for: 1, type: "suburb")?.rarity == .legendary)
    }
}
