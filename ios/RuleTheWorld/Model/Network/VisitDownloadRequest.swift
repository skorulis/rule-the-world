import ASKCore
import Foundation

struct VisitDownloadRequest: HTTPRequest {
    typealias ResponseType = [HexInfo]

    let endpoint = "api/hex-visits"
    let method = "GET"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String] = [:]

    func decode(data: Data, response: URLResponse) throws -> [HexInfo] {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(VisitDownloadResponse.self, from: data)
        return try payload.visits.map { info in
            if let totals = info.totals {
                guard totals.totalVisits >= 0, totals.rivalScore.isFinite, totals.rivalScore >= 0 else {
                    throw URLError(.cannotParseResponse)
                }
            }
            return info
        }
    }
}
