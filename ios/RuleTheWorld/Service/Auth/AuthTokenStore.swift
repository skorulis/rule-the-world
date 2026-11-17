import ASKCore
import Foundation

final class AuthTokenStore {
    private static let key = "session-token"

    private let keyValueStore: SecureKeyValueStore

    init(keyValueStore: SecureKeyValueStore) {
        self.keyValueStore = keyValueStore
    }

    var token: String? {
        keyValueStore.string(forKey: Self.key)
    }

    func save(_ token: String) {
        keyValueStore.set(token, forKey: Self.key)
    }

    func clear() {
        keyValueStore.removeObject(forKey: Self.key)
    }
}
