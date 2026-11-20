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
        let payload = try JSONDecoder().decode(HexTotals.self, from: data)
        guard payload.totalVisits >= 0, payload.rivalScore.isFinite, payload.rivalScore >= 0 else {
            throw URLError(.cannotParseResponse)
        }
        return payload
    }
}
