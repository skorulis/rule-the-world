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

    private func makeService(
        status: Int = 200, visitsStatus: Int = 200, visitsBody: String = "{\"visits\":[]}"
    ) -> FakeURLSession {
        FakeURLSession { request in
            if request.url?.path == "/api/hex-visits" {
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: visitsStatus, httpVersion: nil, headerFields: nil
                )!
                return (Data(visitsBody.utf8), response)
            }
            let token = request.url?.path.contains("sign-up") == true ? "sign-up-token" : "sign-in-token"
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["set-auth-token": token]
            )!
            return (Data(), response)
        }
    }

    private func makeManager(
        service: FakeURLSession, tokenStore: AuthTokenStore, database: AppDatabase,
        visitStore: HexInfoStore? = nil
    ) -> AuthManager {
        AuthManager(
            service: AuthService(urlSession: service),
            authenticatedService: AuthenticatedService(tokenStore: tokenStore, urlSession: service),
            tokenStore: tokenStore, database: database, visitStore: visitStore
        )
    }

    @Test func startsSignedOutWithoutStoredToken() throws {
        let manager = makeManager(
            service: makeService(),
            tokenStore: makeStore(),
            database: try AppDatabase.inMemory()
        )
        #expect(manager.isSignedIn == false)
    }

    @Test func startsSignedInWithStoredToken() throws {
        let manager = makeManager(
            service: makeService(),
            tokenStore: makeStore(token: "existing"),
            database: try AppDatabase.inMemory()
        )
        #expect(manager.isSignedIn == true)
    }

    @Test func signInStoresTokenAndMarksSignedIn() async throws {
        let store = makeStore()
        let manager = makeManager(
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
        let manager = makeManager(
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
        let manager = makeManager(
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

    @Test func signInRestoresVisitsAndRefreshesSharedSnapshot() async throws {
        let database = try AppDatabase.inMemory()
        let visits = HexInfoStore(database: database)
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        let manager = makeManager(
            service: makeService(visitsBody: """
                {"visits":[{"totalVisits":105,"rivalScore":30.25,"userVisit":{
                "cell":"8a283082876ffff","lastVisit":"2026-11-20T10:00:00.000Z",
                "score":12.5,"lastScore":0.5,"total":42}}]}
                """),
            tokenStore: makeStore(), database: database, visitStore: visits
        )

        try await manager.signIn(email: "a@b.c", password: "pw")

        #expect(try await visits.visit(for: cell)?.score == 12.5)
        #expect(try await visits.visit(for: cell)?.lastScore == 0.5)
        #expect(visits.snapshot.states[cell] != nil)
        #expect(try await HexVisitLogStore(database: database).all().isEmpty)
        #expect(manager.isSignedIn)
    }

    @Test func failedRestoreLeavesLoginRetryableWithoutSavingToken() async throws {
        let tokens = makeStore()
        let manager = makeManager(
            service: makeService(visitsStatus: 500), tokenStore: tokens,
            database: try AppDatabase.inMemory()
        )

        await #expect(throws: (any Error).self) {
            try await manager.signIn(email: "a@b.c", password: "pw")
        }

        #expect(!manager.isSignedIn)
        #expect(tokens.token == nil)
    }

    @Test func failedRestorePreservesPreviousToken() async throws {
        let tokens = makeStore(token: "existing")
        let manager = makeManager(
            service: makeService(visitsStatus: 500), tokenStore: tokens,
            database: try AppDatabase.inMemory()
        )

        await #expect(throws: (any Error).self) {
            try await manager.signIn(email: "a@b.c", password: "pw")
        }

        #expect(manager.isSignedIn)
        #expect(tokens.token == "existing")
    }

    @Test func signOutClearsToken() async throws {
        let store = makeStore()
        let manager = makeManager(
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
        let visitStore = HexInfoStore(database: database)
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        try await visitStore.recordVisit(cell)
        let manager = makeManager(
            service: makeService(),
            tokenStore: makeStore(),
            database: database
        )

        manager.signOut()

        #expect(try await visitStore.visit(for: cell) == nil)
    }
}
