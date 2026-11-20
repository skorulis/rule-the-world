import ASKCore
import Foundation

struct TokenRequest<Body: Encodable>: HTTPRequest {
    typealias ResponseType = String

    let endpoint: String
    let method = "POST"
    let body: Data?
    let headers: [String: String]
    let params: [String: String] = [:]

    init(endpoint: String, body: Body, origin: String?) {
        self.endpoint = endpoint
        self.body = try? JSONEncoder().encode(body)
        var headers = ["Content-Type": "application/json"]
        if let origin {
            headers["Origin"] = origin
        }
        self.headers = headers
    }

    func decode(data: Data, response: URLResponse) throws -> String {
        if let httpResponse = response as? HTTPURLResponse,
           let token = httpResponse.value(forHTTPHeaderField: "set-auth-token") {
            return token
        }

        if let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data),
           let token = decoded.token {
            return token
        }

        throw AuthError.missingToken
    }
}
