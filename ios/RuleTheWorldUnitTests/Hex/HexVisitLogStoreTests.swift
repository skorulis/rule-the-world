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
}
