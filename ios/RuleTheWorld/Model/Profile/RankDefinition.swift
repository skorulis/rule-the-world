import Foundation

nonisolated struct RankDefinition: Decodable, Sendable {
    let number: Int
    let name: String
    let description: String
}
