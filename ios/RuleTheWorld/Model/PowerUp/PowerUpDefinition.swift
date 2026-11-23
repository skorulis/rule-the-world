import Foundation

nonisolated enum PowerUpType: String, Decodable, Sendable {
    case revisit
    case exploration
    case fortification

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }
}

nonisolated enum PowerUpRarity: String, Decodable, Sendable, CaseIterable, Comparable {
    case common
    case rare
    case epic

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    private var sortOrder: Int {
        switch self {
        case .common: 0
        case .rare: 1
        case .epic: 2
        }
    }

    static func < (lhs: PowerUpRarity, rhs: PowerUpRarity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

nonisolated struct PowerUpDefinition: Decodable, Sendable, Identifiable {
    let id: Int
    let type: PowerUpType
    let rarity: PowerUpRarity
    let bonus: Int
    let description: String

    var displayName: String {
        "\(rarity.displayName) \(type.displayName)"
    }

    var formattedDescription: String {
        description.replacingOccurrences(of: "{bonus}", with: String(bonus))
    }
}
