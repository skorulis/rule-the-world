import ASKCore
import Foundation

final class BannerStore {
    enum SaveError: Error {
        case missingIdentity, writeFailed
    }

    /// ID used for the banner created during sign-up, before the real user ID is known.
    static let setupUserID = "__banner_setup__"

    private let keyValueStore: PKeyValueStore

    init(keyValueStore: PKeyValueStore) {
        self.keyValueStore = keyValueStore
    }

    func banner(for userID: String) -> BannerConfiguration {
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .default }
        return (try? keyValueStore.codable(forKey: key(for: userID))) ?? .default
    }

    func save(_ banner: BannerConfiguration, for userID: String) throws {
        guard !userID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SaveError.missingIdentity
        }
        let data = try JSONEncoder().encode(banner)
        let storageKey = key(for: userID)
        keyValueStore.set(data, forKey: storageKey)
        guard keyValueStore.data(forKey: storageKey) == data else { throw SaveError.writeFailed }
    }

    /// Moves a banner saved under `setupUserID` to the real user ID, if one exists.
    func applySetupBanner(to userID: String) {
        let setupKey = key(for: Self.setupUserID)
        guard userID != Self.setupUserID, let data = keyValueStore.data(forKey: setupKey) else { return }
        keyValueStore.set(data, forKey: key(for: userID))
        keyValueStore.removeObject(forKey: setupKey)
    }

    private func key(for userID: String) -> String { "banner-v1:\(userID)" }
}
