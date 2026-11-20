import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ProfileViewModelTests {
    private let cellA = HexCell(rawValue: 0x8A283082876FFFF)
    private let cellB = HexCell(rawValue: 0x8A283082872FFFF)

    private func makeModel() throws -> (ProfileViewModel, HexVisitStore) {
        let database = try AppDatabase.inMemory()
        let store = HexVisitStore(database: database)
        let manager = AuthManager(
            service: AuthService(urlSession: FakeURLSession { _ in
                throw URLError(.unsupportedURL)
            }),
            tokenStore: AuthTokenStore(keyValueStore: InMemoryKeyValueStore()),
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
            HexVisit(cell: $0, lastVisit: .now, score: 1, lastScore: 1)
        }

        try await store.restore(visits)
        #expect(model.visitedHexCount == 2)

        try await store.restore(visits)
        #expect(model.visitedHexCount == 2)
    }
}
