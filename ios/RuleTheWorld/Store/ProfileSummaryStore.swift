import ASKCore
import Foundation

final class ProfileSummaryStore {
    static let key = "profile-summary"

    private let keyValueStore: PKeyValueStore

    init(keyValueStore: PKeyValueStore) {
        self.keyValueStore = keyValueStore
    }

    var summary: ProfileSummary? {
        try? keyValueStore.codable(forKey: Self.key)
    }

    func save(_ summary: ProfileSummary) {
        try? keyValueStore.set(codable: summary, forKey: Self.key)
    }

    func update(rankings: [ProfileSummary.Ranking]) {
        guard var summary else { return }
        summary.rankings = rankings
        save(summary)
    }

    func clear() {
        keyValueStore.removeObject(forKey: Self.key)
    }
}
