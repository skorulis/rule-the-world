import ASKCore
import Foundation

struct HexTotalsRequest: HTTPRequest {
    typealias ResponseType = HexTotals

    let endpoint: String
    let method = "GET"
    let params: [String: String] = [:]
    let headers: [String: String] = [:]
    let body: Data? = nil

    init(cell: HexCell) {
        endpoint = "api/hex-visits/\(cell.description)"
    }

    func decode(data: Data, response: URLResponse) throws -> HexTotals {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(HexTotalsResponse.self, from: data)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let fallback = ISO8601DateFormatter()
        let visit = try payload.userVisit.map { visit in
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
        guard payload.totalVisits >= 0, payload.rivalScore.isFinite, payload.rivalScore >= 0 else {
            throw URLError(.cannotParseResponse)
        }
        return HexTotals(totalVisits: payload.totalVisits, rivalScore: payload.rivalScore, userVisit: visit)
    }
}
