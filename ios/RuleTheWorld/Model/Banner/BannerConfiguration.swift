import Foundation

nonisolated struct BannerConfiguration: Codable, Equatable, Sendable {
    private(set) var schemaVersion = 1
    var pattern: BannerPattern = .chevron
    var backgroundColor: BannerColor = .navy
    var patternColor: BannerColor = .purple
    var emblem: BannerEmblem = .compass
    var emblemColor: BannerColor = .gold

    static let `default` = BannerConfiguration()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, pattern, backgroundColor, patternColor, emblem, emblemColor
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .schemaVersion)
        guard version == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion, in: values, debugDescription: "Unsupported banner version"
            )
        }
        pattern = BannerPattern(rawValue: try values.decode(String.self, forKey: .pattern)) ?? .chevron
        backgroundColor = BannerColor(rawValue: try values.decode(String.self, forKey: .backgroundColor)) ?? .navy
        patternColor = BannerColor(rawValue: try values.decode(String.self, forKey: .patternColor)) ?? .purple
        emblem = BannerEmblem(rawValue: try values.decode(String.self, forKey: .emblem)) ?? .compass
        emblemColor = BannerColor(rawValue: try values.decode(String.self, forKey: .emblemColor)) ?? .gold
    }

    func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(schemaVersion, forKey: .schemaVersion)
        try values.encode(pattern.rawValue, forKey: .pattern)
        try values.encode(backgroundColor.rawValue, forKey: .backgroundColor)
        try values.encode(patternColor.rawValue, forKey: .patternColor)
        try values.encode(emblem.rawValue, forKey: .emblem)
        try values.encode(emblemColor.rawValue, forKey: .emblemColor)
    }

    mutating func shuffle(using generator: inout some RandomNumberGenerator) {
        let previous = self
        pattern = BannerPattern.allCases.randomElement(using: &generator) ?? .solid
        emblem = BannerEmblem.allCases.randomElement(using: &generator) ?? .crown
        backgroundColor = BannerColor.allCases.randomElement(using: &generator) ?? .navy
        patternColor = BannerColor.allCases.filter { $0 != backgroundColor }
            .randomElement(using: &generator) ?? .gold
        emblemColor = BannerColor.allCases.filter { $0 != backgroundColor && $0 != patternColor }
            .randomElement(using: &generator) ?? .ivory
        if self == previous {
            emblem = emblem == .crown ? .star : .crown
        }
    }
}
