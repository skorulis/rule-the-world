import Foundation

nonisolated enum PowerUpType: String, Decodable, Sendable {
    case revisit
    case exploration
    case fortification
    case attack
    case conquer
    case defend

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

nonisolated struct PowerUpDefinition: Decodable, Sendable, Identifiable {
    let id: Int
    let type: PowerUpType
    let rarity: Rarity
    let bonus: Int
    let description: String

    var displayName: String {
        "\(rarity.displayName) \(type.displayName)"
    }

    var formattedDescription: String {
        description.replacingOccurrences(of: "{bonus}", with: String(bonus))
    }
}
