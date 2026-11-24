import Foundation

nonisolated struct LootBoxDefinition: Decodable, Sendable, Identifiable {
    let id: Int
    let name: String
    let cost: Int
    let rarity: Rarity
}
