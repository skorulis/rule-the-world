import Foundation
import Testing
@testable import RuleTheWorld

struct RegionNameCatalogTests {
    @Test func resolvesNumericIDsAndDropsMissingOrBlankNames() {
        let catalog = RegionNameCatalog(data: Data(#"{"1234":" Australia ","2":" ","0":"Invalid"}"#.utf8))
        #expect(catalog.name(for: 1234) == "Australia")
        #expect(catalog.name(for: 2) == nil)
        #expect(catalog.name(for: 3) == nil)
        #expect(catalog.name(for: 0) == nil)
        #expect(catalog.name(for: -1) == nil)
    }

    @Test func missingOrMalformedCatalogIsSilent() {
        #expect(RegionNameCatalog(data: nil).name(for: 1) == nil)
        #expect(RegionNameCatalog(data: Data("invalid".utf8)).name(for: 1) == nil)
    }

    @Test func bundledLookupCoversEveryCountryWithItsCanonicalName() throws {
        let bundle = Bundle(for: HexMapViewModel.self)
        let url = try #require(bundle.url(forResource: "countries-medium", withExtension: "geojson")
            ?? bundle.url(forResource: "countries-medium", withExtension: "geojson", subdirectory: "Regions"))
        let collection = try JSONDecoder().decode(Collection.self, from: Data(contentsOf: url))
        let catalog = RegionNameCatalog(bundle: bundle)
        #expect(collection.features.count == 242)
        for feature in collection.features {
            let id = try #require(Int64(feature.properties.id))
            #expect(catalog.name(for: id) == feature.properties.name)
        }
    }

    private struct Collection: Decodable {
        let features: [Feature]
    }

    private struct Feature: Decodable {
        let properties: Properties
    }

    private struct Properties: Decodable {
        let id: String
        let name: String
    }
}
