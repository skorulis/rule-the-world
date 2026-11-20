import Foundation

nonisolated struct HexTotalsResponse: Decodable {
    let totalVisits: Int
    let rivalScore: Double
    let userVisit: HexVisit?
}
