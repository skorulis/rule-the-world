import Foundation

nonisolated struct HexInfo: Decodable, Hashable, Sendable {
    let totalVisits: Int
    let rivalScore: Double
    let userVisit: HexVisit?
}
