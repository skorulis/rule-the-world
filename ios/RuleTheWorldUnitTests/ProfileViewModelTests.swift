import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ProfileViewModelTests {
    private let cellA = HexCell(rawValue: 0x8A283082876FFFF)
    private let cellB = HexCell(rawValue: 0x8A283082872FFFF)

    private func makeModel() throws -> (ProfileViewModel, HexInfoStore) {
        let database = try AppDatabase.inMemory()
        let store = HexInfoStore(database: database)
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        let session = FakeURLSession { _ in
            throw URLError(.unsupportedURL)
        }
        let manager = AuthManager(
            service: AuthService(urlSession: session),
            authenticatedService: AuthenticatedService(tokenStore: tokenStore, urlSession: session),
            tokenStore: tokenStore,
            database: database,
            visitStore: store
        )
        return (ProfileViewModel(authManager: manager, store: store), store)
    }

    @Test func visitedHexCountStartsAtZero() throws {
        let (model, _) = try makeModel()
        #expect(model.visitedHexCount == 0)
    }

    @Test func visitedHexCountTracksDistinctHexesIncludingPartialVisits() async throws {
        let (model, store) = try makeModel()

        _ = try await store.recordVisit(cellA)
        #expect(model.visitedHexCount == 1)

        _ = try await store.recordVisit(cellA)
        #expect(model.visitedHexCount == 1)

        _ = try await store.recordVisit(cellB, score: 0.5)
        #expect(model.visitedHexCount == 2)
    }

    @Test func visitedHexCountIncludesRestoredHexesWithoutDuplicates() async throws {
        let (model, store) = try makeModel()
        _ = try await store.recordVisit(cellA)
        let visits = [cellA, cellB].map {
            HexInfo(
                cell: $0, totals: HexTotals(totalVisits: 1, rivalScore: 0),
                userVisit: HexVisit(lastVisit: .now, score: 1, lastScore: 1)
            )
        }

        try await store.restore(visits)
        #expect(model.visitedHexCount == 2)

        try await store.restore(visits)
        #expect(model.visitedHexCount == 2)
    }
}
