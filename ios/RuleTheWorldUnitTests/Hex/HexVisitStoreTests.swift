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
        #expect(visit.total == 1)
        #expect(visit.lastScore == 1)
        #expect(visit.lastVisit == date)
    }

    @MainActor
    @Test func secondVisitSameDayDoesNotExceedDailyCap() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell, at: Date(timeIntervalSince1970: 1_700_000_000))
        let date = Date(timeIntervalSince1970: 1_700_000_100)
        let visit = try await store.recordVisit(cell, at: date)
        #expect(visit.total == 2)
        #expect(visit.score == 1)
        #expect(visit.lastScore == 1)
        #expect(visit.lastVisit == date)
    }

    @MainActor
    @Test func visitOnLaterDayScoresAgain() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell, at: Date(timeIntervalSince1970: 1_700_000_000))
        let visit = try await store.recordVisit(cell, at: Date(timeIntervalSince1970: 1_700_000_000 + 86_400 * 2))
        #expect(visit.score == 2)
        #expect(visit.lastScore == 1)
    }

    @Test func restoreIsIdempotentAndPreservesNewerLocalVisits() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        let localDate = Date(timeIntervalSince1970: 1_800_000_000)
        let localOnly = HexCell(rawValue: 0x8A2830828007FFF)
        _ = try await store.recordVisit(cell, at: localDate)
        _ = try await store.recordVisit(localOnly, at: localDate)
        let remote = HexVisit(
            cell: cell, lastVisit: localDate.addingTimeInterval(-86_400), score: 10, lastScore: 0.5, total: 42
        )

        try await store.restore([remote])
        try await store.restore([remote])

        let restored = try #require(try await store.visit(for: cell))
        #expect(restored.score == 10)
        #expect(restored.total == 42)
        #expect(restored.lastVisit == localDate)
        #expect(restored.lastScore == 1)
        #expect(try await store.visit(for: localOnly) != nil)
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
        #expect(store.snapshot.states[cell] == .visited)
    }

    @MainActor
    @Test func snapshotMarksLowScoreCellAsPartialVisit() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell, score: 0.5)
        #expect(store.snapshot.states[cell] == .partialVisit)
    }
}
