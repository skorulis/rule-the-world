import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private let service: AuthService
    private let authenticatedService: AuthenticatedService
    private let tokenStore: AuthTokenStore
    private let database: AppDatabase
    private let visitStore: HexInfoStore
    private(set) var isSignedIn: Bool

    init(
        service: AuthService, authenticatedService: AuthenticatedService,
        tokenStore: AuthTokenStore, database: AppDatabase,
        visitStore: HexInfoStore? = nil
    ) {
        self.service = service
        self.authenticatedService = authenticatedService
        self.tokenStore = tokenStore
        self.database = database
        self.visitStore = visitStore ?? HexInfoStore(database: database)
        self.isSignedIn = tokenStore.token != nil
    }

    func signIn(email: String, password: String) async throws {
        let token = try await service.signIn(email: email, password: password)
        try await finishLogin(token: token)
    }

    func signUp(name: String, email: String, password: String) async throws {
        let token = try await service.signUp(name: name, email: email, password: password)
        try await finishLogin(token: token)
    }

    private func finishLogin(token: String) async throws {
        let previousToken = tokenStore.token
        tokenStore.save(token)
        do {
            let visits = try await authenticatedService.fetchVisits()
            try Task.checkCancellation()
            try await visitStore.restore(visits)
            isSignedIn = true
        } catch {
            if let previousToken {
                tokenStore.save(previousToken)
            } else {
                tokenStore.clear()
            }
            throw error
        }
    }

    func signOut() {
        try? database.erase()
        tokenStore.clear()
        isSignedIn = false
    }
}
