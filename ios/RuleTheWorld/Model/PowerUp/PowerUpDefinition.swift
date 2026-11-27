import Foundation

nonisolated enum PowerUpType: String, Decodable, Sendable {
    case attack
    case defend
    case explore

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

nonisolated struct PowerUpDefinition: Decodable, Sendable, Identifiable {
    let id: Int
    let type: PowerUpType
    let rarity: Rarity
    let bonus: Int
    let squares: Int
    let description: String

    var displayName: String {
        "\(rarity.displayName) \(type.displayName)"
    }

    var formattedDescription: String {
        description
            .replacingOccurrences(of: "{bonus}", with: String(bonus))
            .replacingOccurrences(of: "{squares}", with: String(squares))
    }
}
