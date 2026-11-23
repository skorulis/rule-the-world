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
