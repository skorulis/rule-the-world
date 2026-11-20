import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct HexVisitLogStoreTests {
    private let cellA = HexCell(rawValue: 0x8A283082876FFFF)
    private let cellB = HexCell(rawValue: 0x8A283082872FFFF)

    private func makeStore() throws -> HexVisitLogStore {
        try HexVisitLogStore(database: AppDatabase.inMemory())
    }

    private func entry(
        cell: HexCell,
        score: Double = 1,
        speed: Double? = nil,
        timestamp: Date = Date(timeIntervalSince1970: 1_700_000_000),
        locationType: LocationType = .foreground
    ) -> HexVisitLog {
        HexVisitLog(
            timestamp: timestamp,
            cell: cell,
            latitude: -33.89,
            longitude: 151.19,
            speed: speed,
            score: score,
            locationType: locationType
        )
    }

    @Test func firstRecordInsertsAndReturnsId() async throws {
        let store = try makeStore()
        let recorded = try await store.record(entry(cell: cellA))
        #expect(recorded.id != nil)
        #expect(recorded.count == 1)
        let all = try await store.all()
        #expect(all.count == 1)
        #expect(all.first?.cell == cellA)
    }

    @Test func secondSameCellRecordMergesInPlace() async throws {
        let store = try makeStore()
        let first = try await store.record(entry(cell: cellA, score: 0.5, speed: 8))
        let second = try await store.record(entry(
            cell: cellA,
            score: 1,
            speed: 2,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100)
        ))
        #expect(second.id == first.id)
        #expect(second.score == 1)
        #expect(second.speed == 2)
        #expect(second.timestamp == Date(timeIntervalSince1970: 1_700_000_100))
        let all = try await store.all()
        #expect(all.count == 1)
        #expect(all.first?.score == 1)
    }

    @Test func sameCellMergesIncrementCount() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA, score: 0.5))
        let second = try await store.record(entry(cell: cellA, score: 1))
        #expect(second.count == 2)
        let third = try await store.record(entry(cell: cellA, score: 0.75))
        #expect(third.count == 3)
        #expect(try await store.all().count == 1)
    }

    @Test func mergeTakesLocationTypeFromWinningEntry() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA, score: 0.5, locationType: .foreground))
        let merged = try await store.record(entry(cell: cellA, score: 1, locationType: .background))
        #expect(merged.locationType == .background)
        #expect(merged.score == 1)
    }

    @Test func differentCellAppendsNewRow() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA))
        _ = try await store.record(entry(cell: cellB))
        let all = try await store.all()
        #expect(all.count == 2)
        #expect(all.map(\.cell) == [cellA, cellB])
    }

    @Test func alternatingCellsAppendRows() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA))
        _ = try await store.record(entry(cell: cellB))
        _ = try await store.record(entry(cell: cellA))
        let all = try await store.all()
        #expect(all.count == 3)
        #expect(all.map(\.cell) == [cellA, cellB, cellA])
    }

    @Test func acknowledgedVisitsPersistAndAreExcludedFromPending() async throws {
        let database = try AppDatabase.inMemory()
        let store = HexVisitLogStore(database: database)
        let first = try await store.record(entry(cell: cellA))
        let second = try await store.record(entry(cell: cellB))
        try await store.markUploaded([first, second], acceptedIDs: [first.uploadID])

        let reopened = HexVisitLogStore(database: database)
        #expect(try await reopened.pending().map(\.uploadID) == [second.uploadID])
        #expect(try await reopened.all().first?.uploaded == true)
    }

    @Test func editsDuringUploadRemainPending() async throws {
        let store = try makeStore()
        let snapshot = try await store.record(entry(cell: cellA, score: 0.5))
        let changed = try await store.record(entry(cell: cellA, score: 1))
        try await store.markUploaded([snapshot], acceptedIDs: [snapshot.uploadID])
        #expect(changed.uploadID == snapshot.uploadID)
        #expect(try await store.pending().first?.count == 2)
        try await store.markUploaded([changed], acceptedIDs: [changed.uploadID])
        #expect(try await store.pending().isEmpty)
    }

    @Test func uploadedRowsAreNotMergedWithNewSamples() async throws {
        let store = try makeStore()
        let first = try await store.record(entry(cell: cellA))
        try await store.markUploaded([first], acceptedIDs: [first.uploadID])
        let second = try await store.record(entry(cell: cellA))
        #expect(second.id != first.id)
        #expect(second.uploadID != first.uploadID)
        #expect(try await store.pending().map(\.uploadID) == [second.uploadID])
    }

    @Test func sameCellDoesNotMergeAcrossUTCMidnight() async throws {
        let store = try makeStore()
        let midnight = Date(timeIntervalSince1970: 1_700_006_400)
        let first = try await store.record(entry(cell: cellA, timestamp: midnight.addingTimeInterval(-1)))
        let second = try await store.record(entry(cell: cellA, timestamp: midnight))
        #expect(second.id != first.id)
        #expect(try await store.pending().count == 2)
    }

    @Test func pendingPaginationRespectsBoundsAndLimit() async throws {
        let store = try makeStore()
        let first = try await store.record(entry(cell: cellA))
        let second = try await store.record(entry(cell: cellB))
        let third = try await store.record(entry(cell: cellA))
        #expect(try await store.pending(limit: 1).map(\.id) == [first.id])
        let after = try #require(first.id)
        let through = try #require(second.id)
        #expect(try await store.pending(after: after, through: through).map(\.id) == [second.id])
        #expect(third.id != second.id)
    }

    @Test func visitCountSumsCountsForCellOnly() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA))
        _ = try await store.record(entry(cell: cellA))
        _ = try await store.record(entry(cell: cellB))
        _ = try await store.record(entry(cell: cellA))
        #expect(try await store.visitCount(for: cellA) == 3)
        #expect(try await store.visitCount(for: cellB) == 1)
        #expect(try await store.visitCount(for: HexCell(rawValue: 1)) == 0)
    }

    @Test func oldAcknowledgementsCannotMarkRowsAfterSignOutErase() async throws {
        let database = try AppDatabase.inMemory()
        let store = HexVisitLogStore(database: database)
        let old = try await store.record(entry(cell: cellA))
        try database.erase()
        let new = try await store.record(entry(cell: cellA))
        try await store.markUploaded([old], acceptedIDs: [old.uploadID])
        #expect(new.uploadID != old.uploadID)
        #expect(try await store.pending().map(\.uploadID) == [new.uploadID])
    }
}
