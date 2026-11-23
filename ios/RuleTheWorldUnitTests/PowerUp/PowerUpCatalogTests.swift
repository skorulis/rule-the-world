import Foundation
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

    @Test func raritiesSortByProgression() {
        #expect([PowerUpRarity.epic, .common, .rare].sorted() == [.common, .rare, .epic])
        #expect(PowerUpRarity.rare.displayName == "Rare")
    }
}
