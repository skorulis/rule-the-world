import Foundation
import Testing
@testable import RuleTheWorld

struct LootBoxCatalogTests {
    private let data = Data(#"""
        [
          {"id":1,"name":"Common Reward Box","cost":10,"rarity":"common"},
          {"id":2,"name":"Rare Reward Box","cost":20,"rarity":"rare"}
        ]
        """#.utf8)

    @Test func decodesDefinitionsAndLooksUpById() {
        let catalog = LootBoxCatalog(data: data)
        #expect(catalog.all.count == 2)
        #expect(catalog.definition(for: 1)?.name == "Common Reward Box")
        #expect(catalog.definition(for: 1)?.cost == 10)
        #expect(catalog.definition(for: 2)?.rarity == .rare)
        #expect(catalog.definition(for: 99) == nil)
    }

    @Test func emptyOrInvalidDataYieldsEmptyCatalog() {
        #expect(LootBoxCatalog(data: nil).all.isEmpty)
        #expect(LootBoxCatalog(data: Data("invalid".utf8)).all.isEmpty)
        #expect(LootBoxCatalog(data: Data(#"[{"id":1,"name":"Box","cost":10,"rarity":"mythical"}]"#.utf8)).all.isEmpty)
    }

    @Test func bundledCatalogContainsShopBoxes() {
        let catalog = LootBoxCatalog()
        #expect(catalog.definition(for: 1)?.name == "Common Reward Box")
        #expect(catalog.definition(for: 2)?.name == "Rare Reward Box")
    }
}
