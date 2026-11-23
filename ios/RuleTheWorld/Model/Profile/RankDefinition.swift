import Foundation

nonisolated struct RankDefinition: Decodable, Sendable {
    let number: Int
    let name: String
    let rarity: Rarity
    let description: String
    let icon: String?
}
