import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

nonisolated private struct UploadedVisit: Decodable {
    let id: String
    var uploadID: String { id }
}

nonisolated private struct UploadedVisitBatch: Decodable {
    let visits: [UploadedVisit]
}

@MainActor
private final class VisitUploadSession {
    var calls: [[UploadedVisit]] = []
    var handler: (([UploadedVisit]) async throws -> Set<String>)?

    lazy var service: AuthenticatedService = {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("token")
        return AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { [weak self] request in
            guard let self else { throw CancellationError() }
            return try await self.respond(to: request)
        })
    }()

    private func respond(to request: URLRequest) async throws -> (Data, URLResponse) {
        let entries = try JSONDecoder().decode(UploadedVisitBatch.self, from: request.httpBody ?? Data()).visits
        calls.append(entries)
        let accepted: Set<String>
        if let handler {
            accepted = try await handler(entries)
        } else {
            accepted = Set(entries.map(\.uploadID))
        }
        let data = try JSONEncoder().encode(["acceptedIds": Array(accepted)])
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (data, response)
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
        let uploader = VisitUploadSession()
        let tokens = tokenStore()
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokens)
        try await sync.syncPendingVisits()
        _ = try await store.record(entry())
        tokens.clear()
        try await sync.syncPendingVisits()
        #expect(uploader.calls.isEmpty)
    }

    @Test func successfulUploadsAreNotSentAgain() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        try await sync.syncPendingVisits()
        #expect(uploader.calls.count == 1)
        #expect(try await store.pending().isEmpty)
    }

    @Test func failureLeavesVisitsPendingForRetry() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        uploader.handler = { _ in throw URLError(.notConnectedToInternet) }
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore())
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
        let uploader = VisitUploadSession()
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        #expect(uploader.calls.map(\.count) == [500, 1])
        #expect(try await store.pending().isEmpty)
    }

    @Test func partialAcknowledgementsLeaveOtherVisitsPending() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        let first = try await store.record(entry())
        let second = try await store.record(entry(cell: 0x8A283082872FFFF))
        let uploader = VisitUploadSession()
        uploader.handler = { _ in [first.uploadID] }
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore())
        try await sync.syncPendingVisits()
        #expect(try await store.pending().map(\.uploadID) == [second.uploadID])
    }

    @Test func mutationDuringRequestIsSentOnTheNextCheck() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        uploader.handler = { entries in
            _ = try await store.record(entry(score: 1))
            return Set(entries.map(\.uploadID))
        }
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore())
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
        let uploader = VisitUploadSession()
        uploader.handler = { entries in
            tokens.save("different-session")
            return Set(entries.map(\.uploadID))
        }
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokens)
        try await sync.syncPendingVisits()
        #expect(try await store.pending().count == 1)
    }

    @Test func overlappingChecksDoNotDuplicateRequests() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore())
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
        let uploader = VisitUploadSession()
        uploader.handler = { _ in throw URLError(.notConnectedToInternet) }
        var waits = 0
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore()) {
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
        let uploader = VisitUploadSession()
        var waits = 0
        let sync = HexVisitSyncService(store: store, uploader: uploader.service, tokenStore: tokenStore()) {
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
