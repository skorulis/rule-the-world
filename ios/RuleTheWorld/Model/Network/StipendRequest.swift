import ASKCore
import Foundation

struct StipendRequest: HTTPRequest {
    typealias ResponseType = StipendResponse

    let endpoint = "api/stipend"
    let method = "POST"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String] = [:]

    func decode(data: Data, response: URLResponse) throws -> StipendResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(StipendResponse.self, from: data)
    }
}

nonisolated struct StipendResponse: Decodable, Sendable {
    let stipend: Int
    let coins: Int
}
