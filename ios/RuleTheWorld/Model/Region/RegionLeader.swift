import Foundation

nonisolated struct RegionLeader: Decodable, Sendable {
    let rank: Int
    let name: String
    let owned: Int
}
