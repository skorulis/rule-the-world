import ASKCore
import Foundation

struct HexTotalsRequest: HTTPRequest {
    typealias ResponseType = HexInfo

    let endpoint: String
    let method = "GET"
    let params: [String: String] = [:]
    let headers: [String: String] = [:]
    let body: Data? = nil

    private let cell: HexCell

    init(cell: HexCell) {
        self.cell = cell
        endpoint = "api/hex-visits/\(cell.description)"
    }

    func decode(data: Data, response: URLResponse) throws -> HexInfo {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        let decoder = JSONDecoder()
        decoder.userInfo[HexInfo.cellUserInfoKey] = cell
        var payload = try decoder.decode(HexInfo.self, from: data)
        payload.lastUpdate = .now
        if let totals = payload.totals {
            guard totals.totalVisits >= 0, totals.rivalScore.isFinite, totals.rivalScore >= 0 else {
                throw URLError(.cannotParseResponse)
            }
        }
        return payload
    }
}
