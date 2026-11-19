import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct AuthManagerTests {
    private func makeStore(token: String? = nil) -> AuthTokenStore {
        let store = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        if let token { store.save(token) }
        return store
    }

    private func makeService(status: Int = 200) -> AuthService {
        AuthService(urlSession: FakeURLSession { request in
            let token = request.url?.path.contains("sign-up") == true ? "sign-up-token" : "sign-in-token"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["set-auth-token": token]
            )!
            return (Data(), response)
        })
    }

    @Test func startsSignedOutWithoutStoredToken() throws {
        let manager = AuthManager(
            service: makeService(),
            tokenStore: makeStore(),
            database: try AppDatabase.inMemory()
        )
        #expect(manager.isSignedIn == false)
    }

    @Test func startsSignedInWithStoredToken() throws {
        let manager = AuthManager(
            service: makeService(),
            tokenStore: makeStore(token: "existing"),
            database: try AppDatabase.inMemory()
        )
        #expect(manager.isSignedIn == true)
    }

    @Test func signInStoresTokenAndMarksSignedIn() async throws {
        let store = makeStore()
        let manager = AuthManager(
            service: makeService(),
            tokenStore: store,
            database: try AppDatabase.inMemory()
        )

        try await manager.signIn(email: "a@b.c", password: "pw")

        #expect(manager.isSignedIn == true)
        #expect(store.token == "sign-in-token")
    }

    @Test func signUpStoresTokenAndMarksSignedIn() async throws {
        let store = makeStore()
        let manager = AuthManager(
            service: makeService(),
            tokenStore: store,
            database: try AppDatabase.inMemory()
        )

        try await manager.signUp(name: "Alex", email: "a@b.c", password: "pw")

        #expect(manager.isSignedIn == true)
        #expect(store.token == "sign-up-token")
    }

    @Test func failedSignInStaysSignedOut() async throws {
        let store = makeStore()
        let manager = AuthManager(
            service: makeService(status: 401),
            tokenStore: store,
            database: try AppDatabase.inMemory()
        )

        await #expect(throws: AuthError.self) {
            try await manager.signIn(email: "a@b.c", password: "bad")
        }

        #expect(manager.isSignedIn == false)
        #expect(store.token == nil)
    }

    @Test func signOutClearsToken() async throws {
        let store = makeStore()
        let manager = AuthManager(
            service: makeService(),
            tokenStore: store,
            database: try AppDatabase.inMemory()
        )
        try await manager.signIn(email: "a@b.c", password: "pw")

        manager.signOut()

        #expect(manager.isSignedIn == false)
        #expect(store.token == nil)
    }

    @Test func signOutErasesDatabase() async throws {
        let database = try AppDatabase.inMemory()
        let visitStore = HexVisitStore(database: database)
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        try await visitStore.recordVisit(cell)
        let manager = AuthManager(
            service: makeService(),
            tokenStore: makeStore(),
            database: database
        )

        manager.signOut()

        #expect(try await visitStore.visit(for: cell) == nil)
    }
}
