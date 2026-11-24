import ASKCore
import Foundation

struct HexTotalsRequest: HTTPRequest {
    typealias ResponseType = [HexInfo]

    let endpoint = "api/hex-visits/info"
    let method = "GET"
    let params: [String: String]
    let headers: [String: String] = [:]
    let body: Data? = nil

    init(cells: [HexCell]) {
        params = ["cells": cells.map(\.description).joined(separator: ",")]
    }

    func decode(data: Data, response: URLResponse) throws -> [HexInfo] {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let payload = try JSONDecoder().decode(VisitDownloadResponse.self, from: data)
        return try payload.visits.map { info in
            var info = info
            info.lastUpdate = .now
            if let totals = info.totals {
                guard totals.totalVisits >= 0, totals.rivalScore.isFinite, totals.rivalScore >= 0 else {
                    throw URLError(.cannotParseResponse)
                }
            }
            return info
        }
    }
}
