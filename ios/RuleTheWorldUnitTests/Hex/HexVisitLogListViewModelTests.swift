import ASKCore
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

    private func makeModel(store: HexVisitLogStore, fails: Bool = false) -> HexVisitLogListViewModel {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("token")
        let uploader = AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            if fails { throw URLError(.notConnectedToInternet) }
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: [[String: Any]]]
            let ids = body["visits"]!.compactMap { $0["id"] as? String }
            let data = try JSONSerialization.data(withJSONObject: ["acceptedIds": ids])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        })
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokens)
        return HexVisitLogListViewModel(store: store, syncService: sync)
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
        let model = makeModel(store: store)
        await model.load()
        #expect(model.entries.count == 2)
        #expect(model.entries.first?.cell == cellB)
        #expect(model.errorMessage == nil)
    }

    @Test func manualSyncUploadsPendingEntriesAndUpdatesCount() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA, timestamp: .now))
        let model = makeModel(store: store)
        await model.load()
        #expect(model.pendingCount == 1)
        await model.sync()
        #expect(model.pendingCount == 0)
        #expect(model.entries.first?.uploaded == true)
        #expect(model.errorMessage == nil)
        #expect(!model.isSyncing)
    }

    @Test func manualSyncFailureKeepsOutstandingCountAndShowsError() async throws {
        let store = try makeStore()
        _ = try await store.record(entry(cell: cellA, timestamp: .now))
        let model = makeModel(store: store, fails: true)
        await model.load()
        await model.sync()
        #expect(model.pendingCount == 1)
        #expect(model.errorMessage != nil)
        #expect(!model.isSyncing)
        #expect(try await store.pending().count == 1)
    }

    @Test func countExcludesUploadedEntries() async throws {
        let store = try makeStore()
        let uploaded = try await store.record(entry(cell: cellA, timestamp: .now))
        try await store.markUploaded([uploaded], acceptedIDs: [uploaded.uploadID])
        _ = try await store.record(entry(cell: cellB, timestamp: .now))
        let model = makeModel(store: store)
        await model.load()
        #expect(model.entries.count == 2)
        #expect(model.pendingCount == 1)
    }

    @Test func loadWithEmptyStoreReturnsNoEntries() async throws {
        let store = try makeStore()
        let model = makeModel(store: store)
        await model.load()
        #expect(model.entries.isEmpty)
        #expect(model.errorMessage == nil)
    }
}
