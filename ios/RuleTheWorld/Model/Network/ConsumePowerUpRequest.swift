import ASKCore
import Foundation

nonisolated private struct ConsumePowerUpBody: Encodable {
    struct Location: Encodable {
        let latitude: Double
        let longitude: Double
    }

    let powerup: Int
    let location: Location
}

struct ConsumePowerUpRequest: HTTPRequest {
    typealias ResponseType = ConsumePowerUpResponse

    let endpoint = "api/powerup/consume"
    let method = "POST"
    let params: [String: String] = [:]
    let headers = ["Content-Type": "application/json"]
    let body: Data?

    init(powerup id: Int, latitude: Double, longitude: Double) throws {
        body = try JSONEncoder().encode(ConsumePowerUpBody(
            powerup: id,
            location: .init(latitude: latitude, longitude: longitude)
        ))
    }

    func decode(data: Data, response: URLResponse) throws -> ConsumePowerUpResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ConsumePowerUpResponse.self, from: data)
    }
}

nonisolated struct ConsumePowerUpResponse: Decodable, Sendable {
    let powerups: [String: Int]
    let visits: [HexInfo]
}
