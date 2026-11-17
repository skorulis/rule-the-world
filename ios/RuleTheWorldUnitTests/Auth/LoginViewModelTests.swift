import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct LoginViewModelTests {
    private func makeModel(
        service: AuthServicing = StubAuthService()
    ) -> LoginViewModel {
        LoginViewModel(authManager: AuthManager(
            service: service,
            tokenStore: InMemoryAuthTokenStore()
        ))
    }

    private struct StubAuthService: AuthServicing {
        var error: Error?

        func signIn(email: String, password: String) async throws -> String {
            if let error { throw error }
            return "token"
        }

        func signUp(name: String, email: String, password: String) async throws -> String {
            if let error { throw error }
            return "token"
        }
    }

    @Test func cannotSubmitWithEmptyFields() {
        let model = makeModel()
        #expect(model.canSubmit == false)

        model.email = "a@b.c"
        #expect(model.canSubmit == false)

        model.password = "pw"
        #expect(model.canSubmit == true)
    }

    @Test func signUpModeRequiresName() {
        let model = makeModel()
        model.isSignUpMode = true
        model.email = "a@b.c"
        model.password = "pw"

        #expect(model.canSubmit == false)

        model.name = "Alex"
        #expect(model.canSubmit == true)
        #expect(model.submitTitle == "Sign up")
        #expect(model.modeToggleTitle == "Already have an account? Sign in")
    }

    @Test func submitCallsSignInAndClearsError() async {
        let model = makeModel()
        model.email = "a@b.c"
        model.password = "pw"

        await model.submit()

        #expect(model.errorMessage == nil)
        #expect(model.isLoading == false)
    }

    @Test func submitFailureSetsErrorMessage() async {
        struct Failure: LocalizedError {
            var errorDescription: String? { "boom" }
        }
        let model = makeModel(service: StubAuthService(error: Failure()))
        model.email = "a@b.c"
        model.password = "bad"

        await model.submit()

        #expect(model.errorMessage == "boom")
        #expect(model.isLoading == false)
    }

    @Test func toggleModeClearsError() async {
        struct Failure: LocalizedError {
            var errorDescription: String? { "boom" }
        }
        let model = makeModel(service: StubAuthService(error: Failure()))
        model.email = "a@b.c"
        model.password = "bad"
        await model.submit()
        #expect(model.errorMessage != nil)

        model.toggleMode()

        #expect(model.errorMessage == nil)
        #expect(model.isSignUpMode == true)
    }
}
