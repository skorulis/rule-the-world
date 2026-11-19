import Foundation
import Observation

@Observable
@MainActor
final class AuthManager {
    private let service: AuthService
    private let tokenStore: AuthTokenStore
    private let database: AppDatabase
    private let visitStore: HexVisitStore
    private(set) var isSignedIn: Bool

    init(
        service: AuthService, tokenStore: AuthTokenStore, database: AppDatabase,
        visitStore: HexVisitStore? = nil
    ) {
        self.service = service
        self.tokenStore = tokenStore
        self.database = database
        self.visitStore = visitStore ?? HexVisitStore(database: database)
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
        let visits = try await service.fetchVisits(token: token)
        try Task.checkCancellation()
        try await visitStore.restore(visits)
        tokenStore.save(token)
        isSignedIn = true
    }

    func signOut() {
        try? database.erase()
        tokenStore.clear()
        isSignedIn = false
    }
}
