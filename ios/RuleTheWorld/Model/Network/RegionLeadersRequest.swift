import ASKCore
import Foundation

struct RegionLeadersRequest: HTTPRequest {
    typealias ResponseType = [RegionLeader]

    let endpoint = "api/regions/leaders"
    let method = "GET"
    let params: [String: String]
    let body: Data? = nil
    let headers: [String: String] = [:]

    init(type: RegionType, id: Int64) {
        params = ["type": type.name, "id": String(id)]
    }

    func decode(data: Data, response: URLResponse) throws -> [RegionLeader] {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Payload.self, from: data).leaders
    }

    private struct Payload: Decodable {
        let leaders: [RegionLeader]
    }
}
