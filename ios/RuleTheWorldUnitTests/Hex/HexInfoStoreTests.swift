import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct HexInfoStoreTests {
    private func makeStore() throws -> HexInfoStore {
        try HexInfoStore(database: AppDatabase.inMemory())
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
        #expect(visit.total == 1)
        #expect(visit.score == 1)
        #expect(visit.lastScore == 1)
        #expect(visit.lastVisit == date)
    }

    @MainActor
    @Test func returningToCellSameDayDoesNotAddVisitOrScore() async throws {
        let store = try makeStore()
        let cellA = HexCell(rawValue: 0x8A283082876FFFF)
        let cellB = HexCell(rawValue: 0x8A283082872FFFF)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        _ = try await store.recordVisit(cellA, score: 0.5, at: start)
        _ = try await store.recordVisit(cellB, at: start.addingTimeInterval(60))
        let visit = try await store.recordVisit(cellA, score: 1, at: start.addingTimeInterval(120))
        #expect(visit.total == 1)
        #expect(visit.score == 1)
        #expect(visit.lastScore == 1)
        let sameScore = try await store.recordVisit(cellA, score: 0.25, at: start.addingTimeInterval(180))
        #expect(sameScore.total == 1)
        #expect(sameScore.score == 1)
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
        let remote = HexInfo(
            cell: cell, totals: HexTotals(totalVisits: 50, rivalScore: 3),
            userVisit: HexVisit(
                lastVisit: localDate.addingTimeInterval(-86_400), score: 10, lastScore: 0.5, total: 42
            )
        )

        try await store.restore([remote])
        try await store.restore([remote])

        let restored = try #require(try await store.info(for: cell))
        let restoredVisit = try #require(restored.userVisit)
        #expect(restoredVisit.score == 10)
        #expect(restoredVisit.total == 42)
        #expect(restoredVisit.lastVisit == localDate)
        #expect(restoredVisit.lastScore == 1)
        #expect(restored.totals?.totalVisits == 50)
        #expect(restored.totals?.rivalScore == 3)
        #expect(try await store.info(for: localOnly) != nil)
    }

    @Test func saveKeepsLocalVisitWhenRemoteHasNone() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        let visit = try await store.recordVisit(cell, at: Date(timeIntervalSince1970: 1_700_000_000))

        let saved = try await store.save(
            HexInfo(cell: cell, totals: HexTotals(totalVisits: 7, rivalScore: 9), userVisit: nil)
        )

        #expect(saved.userVisit == visit)
        #expect(saved.totals?.totalVisits == 7)
        #expect(saved.totals?.rivalScore == 9)
        #expect(try await store.info(for: cell)?.totals?.rivalScore == 9)
    }

    @MainActor
    @Test func infoForUnknownCellIsNil() async throws {
        let store = try makeStore()
        let info = try await store.info(for: HexCell(rawValue: 0x8A283082876FFFF))
        #expect(info == nil)
    }

    @MainActor
    @Test func snapshotMarksVisitedCellAsMine() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell)
        #expect(store.snapshot.states[cell] == .visited)
    }

    @MainActor
    @Test func snapshotMarksCellWithoutTotalsAsPartialVisit() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell, score: 0.5)
        #expect(store.snapshot.states[cell] == .partialVisit)
    }

    @MainActor
    @Test func snapshotMarksCellAsOwnedOnlyWhenTotalsAreAvailable() async throws {
        let store = try makeStore()
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        _ = try await store.recordVisit(cell)
        #expect(store.snapshot.states[cell] == .visited)

        _ = try await store.save(
            HexInfo(cell: cell, totals: HexTotals(totalVisits: 7, rivalScore: 0), userVisit: nil)
        )
        #expect(store.snapshot.states[cell] == .owned)

        _ = try await store.save(
            HexInfo(cell: cell, totals: HexTotals(totalVisits: 7, rivalScore: 99), userVisit: nil)
        )
        #expect(store.snapshot.states[cell] == .visited)
    }
}
