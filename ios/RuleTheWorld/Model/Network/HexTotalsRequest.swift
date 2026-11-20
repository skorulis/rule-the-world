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
        let payload = try decoder.decode(HexInfo.self, from: data)
        guard payload.totalVisits >= 0, payload.rivalScore.isFinite, payload.rivalScore >= 0 else {
            throw URLError(.cannotParseResponse)
        }
        return payload
    }
}
