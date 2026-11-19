import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private let service: AuthService
    private let tokenStore: AuthTokenStore
    private let database: AppDatabase
    private(set) var isSignedIn: Bool

    init(service: AuthService, tokenStore: AuthTokenStore, database: AppDatabase) {
        self.service = service
        self.tokenStore = tokenStore
        self.database = database
        self.isSignedIn = tokenStore.token != nil
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
        try? database.erase()
        tokenStore.clear()
        isSignedIn = false
    }
}
