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
    @Test func secondVisitSameDayDoesNotExceedDailyCap() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell, at: Date(timeIntervalSince1970: 1_700_000_000))
        let date = Date(timeIntervalSince1970: 1_700_000_100)
        let visit = try await store.recordVisit(cell, at: date)
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
