import ASKCore
import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private let authManager: AuthManager

    @Resolvable<Resolver>
    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func signOut() {
        authManager.signOut()
    }
}
