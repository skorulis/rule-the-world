import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct LoginViewModelTests {
    private func makeModel(status: Int = 200) -> LoginViewModel {
        let service = AuthService(urlSession: FakeURLSession { request in
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: ["set-auth-token": "token"]
            )!
            return (Data(), response)
        })
        return LoginViewModel(authManager: AuthManager(
            service: service,
            tokenStore: AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        ))
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
        let model = makeModel(status: 401)
        model.email = "a@b.c"
        model.password = "bad"

        await model.submit()

        #expect(model.errorMessage == AuthError.invalidCredentials.localizedDescription)
        #expect(model.isLoading == false)
    }

    @Test func toggleModeClearsError() async {
        let model = makeModel(status: 401)
        model.email = "a@b.c"
        model.password = "bad"
        await model.submit()
        #expect(model.errorMessage != nil)

        model.toggleMode()

        #expect(model.errorMessage == nil)
        #expect(model.isSignUpMode == true)
    }
}
