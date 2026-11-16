import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct HexVisitStoreTests {
    private func makeStore() throws -> HexVisitStore {
        try HexVisitStore(database: AppDatabase.inMemory())
    }

    @MainActor
    @Test func firstVisitScoresOne() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let visit = try await store.recordVisit(cell, at: date)
        #expect(visit.score == 1)
        #expect(visit.lastScore == 1)
        #expect(visit.lastVisit == date)
    }

    @MainActor
    @Test func secondVisitIncrementsScore() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell, at: Date(timeIntervalSince1970: 1_700_000_000))
        let date = Date(timeIntervalSince1970: 1_700_000_100)
        let visit = try await store.recordVisit(cell, at: date)
        #expect(visit.score == 2)
        #expect(visit.lastScore == 1)
        #expect(visit.lastVisit == date)
    }

    @MainActor
    @Test func visitForUnknownCellIsNil() async throws {
        let store = try makeStore()
        let visit = try await store.visit(for: HexCell(rawValue: 0x8A283082876FFFF))
        #expect(visit == nil)
    }

    @MainActor
    @Test func snapshotMarksVisitedCellAsMine() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell)
        #expect(store.snapshot.states[cell] == .mine)
    }
}
