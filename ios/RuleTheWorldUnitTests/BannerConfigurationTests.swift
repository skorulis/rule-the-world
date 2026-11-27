import Foundation
import Testing
@testable import RuleTheWorld

struct BannerConfigurationTests {
    @Test func configurationIsPortableJSON() throws {
        let original = BannerConfiguration.default
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(BannerConfiguration.self, from: data) == original)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(Set(json.keys) == [
            "schemaVersion", "pattern", "backgroundColor", "patternColor", "emblem", "emblemColor"
        ])
        #expect(json["schemaVersion"] as? Int == 1)
        #expect(json["pattern"] as? String == "chevron")
        #expect(json["backgroundColor"] as? String == "navy")
        #expect(json["patternColor"] as? String == "purple")
        #expect(json["emblem"] as? String == "compass")
        #expect(json["emblemColor"] as? String == "gold")
    }

    @Test func everyCatalogOptionRoundTrips() throws {
        for pattern in BannerPattern.allCases {
            for emblem in BannerEmblem.allCases {
                for color in BannerColor.allCases {
                    var original = BannerConfiguration.default
                    original.pattern = pattern
                    original.emblem = emblem
                    original.backgroundColor = color
                    original.patternColor = color
                    original.emblemColor = color
                    let data = try JSONEncoder().encode(original)
                    #expect(try JSONDecoder().decode(BannerConfiguration.self, from: data) == original)
                }
            }
        }
    }

    @Test func unknownOptionIDsUseDefaults() throws {
        let json = """
        {"schemaVersion":1,"pattern":"new-pattern","backgroundColor":"new-color",
        "patternColor":"new-color","emblem":"new-emblem","emblemColor":"new-color"}
        """
        #expect(try JSONDecoder().decode(BannerConfiguration.self, from: Data(json.utf8)) == .default)
    }

    @Test func invalidPayloadsAreRejected() {
        for json in ["{}", "{\"schemaVersion\":2}", "{\"schemaVersion\":\"one\"}"] {
            #expect(throws: (any Error).self) {
                try JSONDecoder().decode(BannerConfiguration.self, from: Data(json.utf8))
            }
        }
    }

    @Test func shufflesAreDeterministicDifferentAndUseDistinctColors() {
        var first = BannerConfiguration.default
        var second = first
        var firstGenerator = BannerTestRandom(seed: 42)
        var secondGenerator = BannerTestRandom(seed: 42)
        for _ in 0..<100 {
            let previous = first
            first.shuffle(using: &firstGenerator)
            second.shuffle(using: &secondGenerator)
            #expect(first == second)
            #expect(first != previous)
            #expect(first.backgroundColor != first.patternColor)
            #expect(first.emblemColor != first.backgroundColor)
            #expect(first.emblemColor != first.patternColor)
        }
    }
}

struct BannerTestRandom: RandomNumberGenerator {
    var seed: UInt64

    mutating func next() -> UInt64 {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return seed
    }
}
