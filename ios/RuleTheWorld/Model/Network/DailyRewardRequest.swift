import ASKCore
import Foundation

struct DailyRewardRequest: HTTPRequest {
    typealias ResponseType = AddPowerUpResponse

    let endpoint = "api/powerup/daily"
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
