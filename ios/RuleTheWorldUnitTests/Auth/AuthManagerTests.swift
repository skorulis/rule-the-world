import Foundation
import Testing
@testable import RuleTheWorld

private struct StubAuthService: AuthServicing {
    var signInToken = "sign-in-token"
    var signUpToken = "sign-up-token"
    var error: Error?

    func signIn(email: String, password: String) async throws -> String {
        if let error { throw error }
        return signInToken
    }

    func signUp(name: String, email: String, password: String) async throws -> String {
        if let error { throw error }
        return signUpToken
    }
}

@MainActor
struct AuthManagerTests {
    @Test func startsSignedOutWithoutStoredToken() {
        let manager = AuthManager(service: StubAuthService(), tokenStore: InMemoryAuthTokenStore())
        #expect(manager.isSignedIn == false)
    }

    @Test func startsSignedInWithStoredToken() {
        let store = InMemoryAuthTokenStore(token: "existing")
        let manager = AuthManager(service: StubAuthService(), tokenStore: store)
        #expect(manager.isSignedIn == true)
    }

    @Test func signInStoresTokenAndMarksSignedIn() async throws {
        let store = InMemoryAuthTokenStore()
        let manager = AuthManager(service: StubAuthService(), tokenStore: store)

        try await manager.signIn(email: "a@b.c", password: "pw")

        #expect(manager.isSignedIn == true)
        #expect(store.load() == "sign-in-token")
    }

    @Test func signUpStoresTokenAndMarksSignedIn() async throws {
        let store = InMemoryAuthTokenStore()
        let manager = AuthManager(service: StubAuthService(), tokenStore: store)

        try await manager.signUp(name: "Alex", email: "a@b.c", password: "pw")

        #expect(manager.isSignedIn == true)
        #expect(store.load() == "sign-up-token")
    }

    @Test func failedSignInStaysSignedOut() async {
        struct Failure: Error {}
        let store = InMemoryAuthTokenStore()
        let manager = AuthManager(
            service: StubAuthService(error: Failure()),
            tokenStore: store
        )

        await #expect(throws: Failure.self) {
            try await manager.signIn(email: "a@b.c", password: "bad")
        }

        #expect(manager.isSignedIn == false)
        #expect(store.load() == nil)
    }

    @Test func signOutClearsToken() async throws {
        let store = InMemoryAuthTokenStore()
        let manager = AuthManager(service: StubAuthService(), tokenStore: store)
        try await manager.signIn(email: "a@b.c", password: "pw")

        manager.signOut()

        #expect(manager.isSignedIn == false)
        #expect(store.load() == nil)
    }
}
