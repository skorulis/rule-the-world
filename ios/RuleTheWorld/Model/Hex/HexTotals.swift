import Foundation

nonisolated struct HexTotals: Decodable, Hashable, Sendable {
    var totalVisits: Int
    var rivalScore: Double
    var userVisit: HexVisit?
}
