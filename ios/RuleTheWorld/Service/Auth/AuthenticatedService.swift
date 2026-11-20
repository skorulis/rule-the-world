import ASKCore
import Foundation

final class AuthenticatedService: HTTPService {
    private let tokenStore: AuthTokenStore

    init(
        tokenStore: AuthTokenStore,
        baseURL: String? = "http://localhost:3001",
        urlSession: URLSessionProtocol = URLSession(configuration: .default)
    ) {
        self.tokenStore = tokenStore
        super.init(baseURL: baseURL, logger: .init(level: .errors), urlSession: urlSession)
    }

    override func modify(request: inout URLRequest) throws {
        try super.modify(request: &request)
        guard let token = tokenStore.token else {
            throw URLError(.userAuthenticationRequired)
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
