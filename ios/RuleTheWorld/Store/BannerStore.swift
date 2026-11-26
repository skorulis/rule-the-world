import ASKCore
import Foundation

final class BannerStore {
    enum SaveError: Error {
        case missingIdentity, writeFailed
    }

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

    private func key(for userID: String) -> String { "banner-v1:\(userID)" }
}
