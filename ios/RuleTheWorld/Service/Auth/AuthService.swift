import ASKCore
import Foundation

enum AuthError: LocalizedError {
    case invalidCredentials
    case missingToken
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password."
        case .missingToken:
            "The server did not return a session token."
        case .transport:
            "Could not reach the server. Check your connection and try again."
        }
    }
}

final class AuthService: HTTPService {
    private let baseURL: String?

    init(
        baseURL: String? = "http://localhost:3001",
        urlSession: URLSessionProtocol = URLSession(configuration: .default)
    ) {
        self.baseURL = baseURL
        super.init(baseURL: baseURL, logger: .init(level: .errors), urlSession: urlSession)
    }

    func signIn(email: String, password: String) async throws -> String {
        try await authenticate(endpoint: "api/auth/sign-in/email", body: [
            "email": email,
            "password": password
        ])
    }

    func signUp(name: String, email: String, password: String) async throws -> String {
        try await authenticate(endpoint: "api/auth/sign-up/email", body: [
            "name": name,
            "email": email,
            "password": password
        ])
    }

    private func authenticate(endpoint: String, body: [String: String]) async throws -> String {
        do {
            return try await execute(request: TokenRequest(endpoint: endpoint, body: body, origin: baseURL))
        } catch let error as URLError {
            if error.code == .badServerResponse {
                throw AuthError.invalidCredentials
            }
            throw AuthError.transport(error)
        }
    }
}

nonisolated struct TokenResponse: Decodable {
    let token: String?
}

private struct TokenRequest<Body: Encodable>: HTTPRequest {
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
