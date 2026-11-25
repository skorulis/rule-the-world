import Foundation

/// Fetches the profile and keeps the cached summary in `ProfileSummaryStore` up to date.
@MainActor
final class ProfileService {
    private let service: AuthenticatedService
    private let store: ProfileSummaryStore

    init(service: AuthenticatedService, store: ProfileSummaryStore) {
        self.service = service
        self.store = store
    }

    var cachedSummary: ProfileSummary? {
        store.summary
    }

    func fetchProfile() async throws -> ProfileSummary {
        let summary = try await service.fetchProfile()
        store.save(summary)
        return summary
    }
}
