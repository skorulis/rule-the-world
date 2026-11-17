import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private let service: AuthServicing
    private let tokenStore: AuthTokenStoring
    private(set) var isSignedIn: Bool

    init(service: AuthServicing, tokenStore: AuthTokenStoring) {
        self.service = service
        self.tokenStore = tokenStore
        self.isSignedIn = tokenStore.load() != nil
    }

    func signIn(email: String, password: String) async throws {
        let token = try await service.signIn(email: email, password: password)
        tokenStore.save(token)
        isSignedIn = true
    }

    func signUp(name: String, email: String, password: String) async throws {
        let token = try await service.signUp(name: name, email: email, password: password)
        tokenStore.save(token)
        isSignedIn = true
    }

    func signOut() {
        tokenStore.clear()
        isSignedIn = false
    }
}
