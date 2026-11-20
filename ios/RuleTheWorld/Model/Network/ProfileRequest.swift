import ASKCore
import Foundation

struct ProfileRequest: HTTPRequest {
    typealias ResponseType = ProfileSummary

    let endpoint = "api/me"
    let method = "GET"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String] = [:]

    func decode(data: Data, response: URLResponse) throws -> ProfileSummary {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(ProfileSummary.self, from: data)
    }
}
