import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct HexVisitLogListViewModelTests {
    private let cellA = HexCell(rawValue: 0x8A283082876FFFF)
    private let cellB = HexCell(rawValue: 0x8A283082872FFFF)

    private func makeStore() throws -> HexVisitLogStore {
        try HexVisitLogStore(database: AppDatabase.inMemory())
    }

    private func entry(
        cell: HexCell,
        timestamp: Date
    ) -> HexVisitLog {
        HexVisitLog(
            timestamp: timestamp,
            cell: cell,
            latitude: -33.89,
            longitude: 151.19,
            speed: nil,
            score: 1
        )
    }

    @Test func loadReturnsEntriesNewestFirst() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(
            cell: cellA,
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        ))
        _ = try await store.record(entry(
            cell: cellB,
            timestamp: Date(timeIntervalSince1970: 1_700_000_100)
        ))
        let model = HexVisitLogListViewModel(store: store)
        await model.load()
        #expect(model.entries.count == 2)
        #expect(model.entries.first?.cell == cellB)
        #expect(model.errorMessage == nil)
    }

    @Test func loadWithEmptyStoreReturnsNoEntries() async throws {
        let store = try makeStore()
        let model = HexVisitLogListViewModel(store: store)
        await model.load()
        #expect(model.entries.isEmpty)
        #expect(model.errorMessage == nil)
    }
}
