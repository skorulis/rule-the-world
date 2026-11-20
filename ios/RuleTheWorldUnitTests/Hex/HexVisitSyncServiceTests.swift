import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
private final class VisitUploaderStub: HexVisitUploading {
    var calls: [[HexVisitLog]] = []
    var handler: (([HexVisitLog]) async throws -> Set<String>)?

    func upload(_ entries: [HexVisitLog]) async throws -> Set<String> {
        calls.append(entries)
        if let handler { return try await handler(entries) }
        return Set(entries.map(\.uploadID))
    }
}

@MainActor
struct HexVisitSyncServiceTests {
    private func entry(cell: UInt64 = 0x8A283082876FFFF, score: Double = 0.5) -> HexVisitLog {
        HexVisitLog(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000), cell: HexCell(rawValue: cell),
            latitude: -33.89, longitude: 151.19, speed: 2, score: score
        )
    }

    private func tokenStore() -> AuthTokenStore {
        let store = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        store.save("token")
        return store
    }

    @Test func emptyOrSignedOutQueuesDoNotMakeNetworkCalls() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        let uploader = VisitUploaderStub()
        let tokens = tokenStore()
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokens)
        try await sync.syncPendingVisits()
        _ = try await store.record(entry())
        tokens.clear()
        try await sync.syncPendingVisits()
        #expect(uploader.calls.isEmpty)
    }

    @Test func successfulUploadsAreNotSentAgain() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploaderStub()
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        try await sync.syncPendingVisits()
        #expect(uploader.calls.count == 1)
        #expect(try await store.pending().isEmpty)
    }

    @Test func failureLeavesVisitsPendingForRetry() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploaderStub()
        uploader.handler = { _ in throw URLError(.notConnectedToInternet) }
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore())
        await #expect(throws: URLError.self) { try await sync.syncPendingVisits() }
        #expect(try await store.pending().count == 1)
        uploader.handler = nil
        try await sync.syncPendingVisits()
        #expect(uploader.calls.count == 2)
        #expect(try await store.pending().isEmpty)
    }

    @Test func chunksOutstandingVisitsAtServerLimit() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        for index in 0..<501 {
            _ = try await store.record(entry(cell: index.isMultiple(of: 2) ? 0x8A283082876FFFF : 0x8A283082872FFFF))
        }
        let uploader = VisitUploaderStub()
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        #expect(uploader.calls.map(\.count) == [500, 1])
        #expect(try await store.pending().isEmpty)
    }

    @Test func partialAcknowledgementsLeaveOtherVisitsPending() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        let first = try await store.record(entry())
        let second = try await store.record(entry(cell: 0x8A283082872FFFF))
        let uploader = VisitUploaderStub()
        uploader.handler = { _ in [first.uploadID] }
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        #expect(try await store.pending().map(\.uploadID) == [second.uploadID])
    }

    @Test func mutationDuringRequestIsSentOnTheNextCheck() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploaderStub()
        uploader.handler = { entries in
            _ = try await store.record(entry(score: 1))
            return Set(entries.map(\.uploadID))
        }
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        #expect(try await store.pending().first?.score == 1)
        uploader.handler = nil
        try await sync.syncPendingVisits()
        #expect(uploader.calls.count == 2)
        #expect(try await store.pending().isEmpty)
    }

    @Test func changedSessionDoesNotAcknowledgeOldRequest() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let tokens = tokenStore()
        let uploader = VisitUploaderStub()
        uploader.handler = { entries in
            tokens.save("different-session")
            return Set(entries.map(\.uploadID))
        }
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokens)
        try await sync.syncPendingVisits()
        #expect(try await store.pending().count == 1)
    }

    @Test func overlappingChecksDoNotDuplicateRequests() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploaderStub()
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore())
        uploader.handler = { entries in
            try await sync.syncPendingVisits()
            return Set(entries.map(\.uploadID))
        }
        try await sync.syncPendingVisits()
        #expect(uploader.calls.count == 1)
    }

    @Test func periodicChecksContinueAfterNetworkFailure() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploaderStub()
        uploader.handler = { _ in throw URLError(.notConnectedToInternet) }
        var waits = 0
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore()) {
            waits += 1
            if waits == 2 { throw CancellationError() }
            #expect(try await store.pending().count == 1)
            uploader.handler = nil
        }
        await sync.run()
        #expect(uploader.calls.count == 2)
        #expect(try await store.pending().isEmpty)
    }

    @Test func runChecksImmediatelyThenAgainAfterTheInterval() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploaderStub()
        var waits = 0
        let sync = HexVisitSyncService(store: store, uploader: uploader, tokenStore: tokenStore()) {
            waits += 1
            if waits == 2 { throw CancellationError() }
            #expect(uploader.calls.count == 1)
            _ = try await store.record(entry(cell: 0x8A283082872FFFF))
        }
        await sync.run()
        #expect(waits == 2)
        #expect(uploader.calls.count == 2)
        #expect(try await store.pending().isEmpty)
    }
}
