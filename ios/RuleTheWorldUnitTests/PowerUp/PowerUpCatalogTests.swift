import Foundation
import SwiftUI
import Testing
@testable import RuleTheWorld

struct PowerUpCatalogTests {
    private let data = Data(#"""
        [
          {"id":1,"type":"attack","rarity":"common","bonus":1,"squares":3,"description":"+{bonus} score to up to {squares} squares"},
          {"id":2,"type":"attack","rarity":"rare","bonus":2,"squares":5,"description":"+{bonus} score to up to {squares} squares"}
        ]
        """#.utf8)

    @Test func decodesDefinitionsAndLooksUpById() {
        let catalog = PowerUpCatalog(data: data)
        #expect(catalog.all.count == 2)
        #expect(catalog.definition(for: 1)?.displayName == "Common Attack")
        #expect(catalog.definition(for: 2)?.rarity == .rare)
        #expect(catalog.definition(for: 99) == nil)
    }

    @Test func emptyOrInvalidDataYieldsEmptyCatalog() {
        #expect(PowerUpCatalog(data: nil).all.isEmpty)
        #expect(PowerUpCatalog(data: Data("invalid".utf8)).all.isEmpty)
    }

    @Test func formattedDescriptionSubstitutesBonusAndSquares() {
        let catalog = PowerUpCatalog(data: data)
        #expect(catalog.definition(for: 2)?.formattedDescription == "+2 score to up to 5 squares")
    }

    @Test func decodesEachType() {
        for (id, type, name) in [(1, PowerUpType.attack, "Attack"), (3, .defend, "Defend"), (5, .explore, "Explore")] {
            let data = Data(#"[{"id":\#(id),"type":"\#(type.rawValue)","rarity":"common","bonus":1,"squares":3,"description":"+{bonus}"}]"#.utf8)
            let definition = PowerUpCatalog(data: data).definition(for: id)
            #expect(definition?.type == type)
            #expect(definition?.displayName == "Common \(name)")
            #expect(definition?.squares == 3)
        }
    }

    @Test func decodesRareDefend() {
        let data = Data(#"[{"id":4,"type":"defend","rarity":"rare","bonus":2,"squares":5,"description":"+{bonus} score to up to {squares} squares you own"}]"#.utf8)
        let definition = PowerUpCatalog(data: data).definition(for: 4)
        #expect(definition?.type == .defend)
        #expect(definition?.rarity == .rare)
        #expect(definition?.displayName == "Rare Defend")
        #expect(definition?.formattedDescription == "+2 score to up to 5 squares you own")
    }

    @Test func unknownTypesFailToDecode() {
        let data = Data(#"[{"id":9,"type":"revisit","rarity":"common","bonus":1,"squares":3,"description":"+{bonus}"}]"#.utf8)
        #expect(PowerUpCatalog(data: data).all.isEmpty)
    }

    @Test func raritiesHaveColors() {
        #expect(Rarity.common.color == Color.gray)
        #expect(Rarity.rare.color == Color.blue)
        #expect(Rarity.epic.color == Color.purple)
        #expect(Rarity.legendary.color == Color.orange)
        #expect(Rarity.mythic.color == Color.red)
    }

    @Test func raritiesSortByProgression() {
        #expect([Rarity.mythic, .legendary, .epic, .common, .rare].sorted() == [.common, .rare, .epic, .legendary, .mythic])
        #expect(Rarity.allCases == [.common, .rare, .epic, .legendary, .mythic])
        #expect(Rarity.rare.displayName == "Rare")
        #expect(Rarity.legendary.displayName == "Legendary")
    }
}
