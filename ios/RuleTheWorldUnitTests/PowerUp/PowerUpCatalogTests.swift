import Foundation
import SwiftUI
import Testing
@testable import RuleTheWorld

struct PowerUpCatalogTests {
    private let data = Data(#"""
        [
          {"id":1,"type":"revisit","rarity":"common","bonus":1,"description":"+{bonus} score"},
          {"id":2,"type":"revisit","rarity":"epic","bonus":3,"description":"+{bonus} score"}
        ]
        """#.utf8)

    @Test func decodesDefinitionsAndLooksUpById() {
        let catalog = PowerUpCatalog(data: data)
        #expect(catalog.all.count == 2)
        #expect(catalog.definition(for: 1)?.displayName == "Common Revisit")
        #expect(catalog.definition(for: 2)?.rarity == .epic)
        #expect(catalog.definition(for: 99) == nil)
    }

    @Test func emptyOrInvalidDataYieldsEmptyCatalog() {
        #expect(PowerUpCatalog(data: nil).all.isEmpty)
        #expect(PowerUpCatalog(data: Data("invalid".utf8)).all.isEmpty)
    }

    @Test func formattedDescriptionSubstitutesBonus() {
        let catalog = PowerUpCatalog(data: data)
        #expect(catalog.definition(for: 2)?.formattedDescription == "+3 score")
    }

    @Test func decodesLegendaryPowerUp() {
        let data = Data(#"[{"id":3,"type":"revisit","rarity":"legendary","bonus":4,"description":"+{bonus} score"}]"#.utf8)
        let definition = PowerUpCatalog(data: data).definition(for: 3)
        #expect(definition?.rarity == .legendary)
        #expect(definition?.displayName == "Legendary Revisit")
    }

    @Test func decodesCommonAttack() {
        let data = Data(#"[{"id":6,"type":"attack","rarity":"common","bonus":1,"description":"+{bonus} score to a nearby square where you already have a score and someone else owns it"}]"#.utf8)
        let definition = PowerUpCatalog(data: data).definition(for: 6)
        #expect(definition?.type == .attack)
        #expect(definition?.displayName == "Common Attack")
        #expect(definition?.bonus == 1)
    }

    @Test func decodesRareConquer() {
        let data = Data(#"[{"id":7,"type":"conquer","rarity":"rare","bonus":1,"description":"+{bonus} score to a nearby contested square"}]"#.utf8)
        let definition = PowerUpCatalog(data: data).definition(for: 7)
        #expect(definition?.type == .conquer)
        #expect(definition?.rarity == .rare)
        #expect(definition?.displayName == "Rare Conquer")
        #expect(definition?.formattedDescription == "+1 score to a nearby contested square")
    }

    @Test func decodesRareDefend() {
        let data = Data(#"[{"id":8,"type":"defend","rarity":"rare","bonus":1,"description":"+{bonus} score to a square you own where a rival is closest to taking the lead"}]"#.utf8)
        let definition = PowerUpCatalog(data: data).definition(for: 8)
        #expect(definition?.type == .defend)
        #expect(definition?.rarity == .rare)
        #expect(definition?.displayName == "Rare Defend")
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
