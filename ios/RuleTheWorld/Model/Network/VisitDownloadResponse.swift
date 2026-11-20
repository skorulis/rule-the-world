import Foundation

nonisolated struct VisitDownloadResponse: Decodable {
    struct Visit: Decodable {
        let cell: String
        let lastVisit: String
        let score: Double
        let lastScore: Double
        let total: Int
    }

    let visits: [Visit]
}
