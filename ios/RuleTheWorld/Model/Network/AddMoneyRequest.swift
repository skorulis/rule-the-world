import ASKCore
import Foundation

struct AddMoneyRequest: HTTPRequest {
    typealias ResponseType = AddMoneyResponse

    let endpoint = "api/debug/cheat/add_money"
    let method = "POST"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String] = [:]

    func decode(data: Data, response: URLResponse) throws -> AddMoneyResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AddMoneyResponse.self, from: data)
    }
}

nonisolated struct AddMoneyResponse: Decodable, Sendable {
    let added: Int
    let coins: Int?
}
