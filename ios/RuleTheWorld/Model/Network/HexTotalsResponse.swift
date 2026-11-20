import Foundation

nonisolated struct HexTotalsResponse: Decodable {
    struct Visit: Decodable {
        let cell: String
        let lastVisit: String
        let score: Double
        let lastScore: Double
        let total: Int
    }

    let totalVisits: Int
    let rivalScore: Double
    let userVisit: Visit?
}
