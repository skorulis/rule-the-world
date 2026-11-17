import ASKCore
import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class LoginViewModel {
    var email = ""
    var password = ""
    var name = ""
    var isSignUpMode = false
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let authManager: AuthManager

    @Resolvable<Resolver>
    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty
            && !password.isEmpty
            && (!isSignUpMode || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    var submitTitle: String {
        isSignUpMode ? "Sign up" : "Sign in"
    }

    var modeToggleTitle: String {
        isSignUpMode ? "Already have an account? Sign in" : "Need an account? Sign up"
    }

    func toggleMode() {
        isSignUpMode.toggle()
        errorMessage = nil
    }

    func submit() async {
        guard canSubmit, !isLoading else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            if isSignUpMode {
                try await authManager.signUp(
                    name: name.trimmingCharacters(in: .whitespaces),
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } else {
                try await authManager.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
