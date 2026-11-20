import ASKCore
import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private let authManager: AuthManager
    private let store: HexInfoStore

    @Resolvable<Resolver>
    init(authManager: AuthManager, store: HexInfoStore) {
        self.authManager = authManager
        self.store = store
    }

    var visitedHexCount: Int {
        store.snapshot.states.count
    }

    func signOut() {
        authManager.signOut()
    }
}
