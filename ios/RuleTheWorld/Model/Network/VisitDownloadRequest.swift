import ASKCore
import Foundation

struct VisitDownloadRequest: HTTPRequest {
    typealias ResponseType = [HexVisit]

    let endpoint = "api/hex-visits"
    let method = "GET"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String]

    init(token: String) {
        headers = ["Authorization": "Bearer \(token)"]
    }

    func decode(data: Data, response: URLResponse) throws -> [HexVisit] {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(VisitDownloadResponse.self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        return try payload.visits.map { visit in
            guard let rawValue = UInt64(visit.cell, radix: 16),
                  let date = formatter.date(from: visit.lastVisit) ?? fallback.date(from: visit.lastVisit),
                  visit.total >= 0, visit.score.isFinite, visit.score >= 0,
                  visit.lastScore.isFinite, (0...1).contains(visit.lastScore) else {
                throw URLError(.cannotParseResponse)
            }
            return HexVisit(
                cell: HexCell(rawValue: rawValue), lastVisit: date,
                score: visit.score, lastScore: visit.lastScore, total: visit.total
            )
        }
    }
}
