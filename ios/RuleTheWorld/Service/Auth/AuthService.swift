import Foundation

protocol AuthServicing {
    func signIn(email: String, password: String) async throws -> String
    func signUp(name: String, email: String, password: String) async throws -> String
}

enum AuthError: LocalizedError {
    case invalidCredentials
    case serverError(Int)
    case missingToken
    case transport(Error)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            "Invalid email or password."
        case .serverError(let statusCode):
            "Server error (\(statusCode)). Please try again."
        case .missingToken:
            "The server did not return a session token."
        case .transport:
            "Could not reach the server. Check your connection and try again."
        }
    }
}

final class AuthService: AuthServicing {
    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "http://localhost:3001")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> String {
        try await authenticate(path: "sign-in/email", body: [
            "email": email,
            "password": password
        ])
    }

    func signUp(name: String, email: String, password: String) async throws -> String {
        try await authenticate(path: "sign-up/email", body: [
            "name": name,
            "email": email,
            "password": password
        ])
    }

    private func authenticate(path: String, body: [String: String]) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("api/auth/\(path)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AuthError.transport(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AuthError.serverError(-1)
        }

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 400, 401:
            throw AuthError.invalidCredentials
        default:
            throw AuthError.serverError(httpResponse.statusCode)
        }

        if let token = httpResponse.value(forHTTPHeaderField: "set-auth-token") {
            return token
        }

        struct TokenResponse: Decodable {
            let token: String?
        }
        if let decoded = try? JSONDecoder().decode(TokenResponse.self, from: data),
           let token = decoded.token {
            return token
        }

        throw AuthError.missingToken
    }
}
