import ASKCore
import Foundation

struct AddPowerUpRequest: HTTPRequest {
    typealias ResponseType = AddPowerUpResponse

    let endpoint = "api/debug/add_powerup"
    let method = "POST"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String] = [:]

    func decode(data: Data, response: URLResponse) throws -> AddPowerUpResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(AddPowerUpResponse.self, from: data)
    }
}

nonisolated struct AddPowerUpResponse: Decodable, Sendable {
    struct GrantedPowerUp: Decodable, Sendable {
        let id: Int
        let name: String
    }

    let powerup: GrantedPowerUp
    let powerups: [String: Int]
}
