import SwiftUI

nonisolated enum Rarity: String, Decodable, Sendable, CaseIterable, Comparable {
    case common
    case rare
    case epic
    case legendary
    case mythic

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var color: Color {
        switch self {
        case .common: .gray
        case .rare: .blue
        case .epic: .purple
        case .legendary: .orange
        case .mythic: .red
        }
    }

    private var sortOrder: Int {
        switch self {
        case .common: 0
        case .rare: 1
        case .epic: 2
        case .legendary: 3
        case .mythic: 4
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}
