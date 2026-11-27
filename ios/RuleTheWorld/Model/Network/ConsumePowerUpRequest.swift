import ASKCore
import Foundation

nonisolated private struct ConsumePowerUpBody: Encodable {
    let powerup: Int
    let cells: [String]
}

struct ConsumePowerUpRequest: HTTPRequest {
    typealias ResponseType = ConsumePowerUpResponse

    let endpoint = "api/powerup/consume"
    let method = "POST"
    let params: [String: String] = [:]
    let headers = ["Content-Type": "application/json"]
    let body: Data?

    init(powerup id: Int, cells: [HexCell]) throws {
        body = try JSONEncoder().encode(ConsumePowerUpBody(
            powerup: id,
            cells: cells.map(\.description)
        ))
    }

    func decode(data: Data, response: URLResponse) throws -> ConsumePowerUpResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            if let error = try? JSONDecoder().decode(ConsumePowerUpFailure.self, from: data) {
                throw error
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ConsumePowerUpResponse.self, from: data)
    }
}

nonisolated struct ConsumePowerUpFailure: Decodable, LocalizedError, Sendable {
    let error: String

    var errorDescription: String? { error }
}

nonisolated struct ConsumePowerUpResponse: Decodable, Sendable {
    let powerups: [String: Int]
    let visits: [HexInfo]
}
