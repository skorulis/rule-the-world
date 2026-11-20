import Foundation
import OSLog

@MainActor
final class HexVisitSyncService {
    private let store: HexVisitLogStore
    private let uploader: any HexVisitUploading
    private let tokenStore: AuthTokenStore
    private let waitForNextCheck: () async throws -> Void
    private var isSyncing = false

    init(
        store: HexVisitLogStore,
        uploader: any HexVisitUploading,
        tokenStore: AuthTokenStore,
        waitForNextCheck: @escaping () async throws -> Void = { try await Task.sleep(for: .seconds(600)) }
    ) {
        self.store = store
        self.uploader = uploader
        self.tokenStore = tokenStore
        self.waitForNextCheck = waitForNextCheck
    }

    func run() async {
        while !Task.isCancelled {
            do {
                try await syncPendingVisits()
            } catch is CancellationError {
                return
            } catch {
                Logger().error("Visit upload failed; pending visits will be retried.")
            }
            do {
                try await waitForNextCheck()
            } catch {
                return
            }
        }
    }

    func syncPendingVisits() async throws {
        guard !isSyncing, let token = tokenStore.token else { return }
        isSyncing = true
        defer { isSyncing = false }
        let lastID = try await store.latest()?.id ?? 0
        var afterID: Int64 = 0
        while afterID < lastID {
            try Task.checkCancellation()
            guard tokenStore.token == token else { return }
            let entries = try await store.pending(after: afterID, through: lastID)
            try Task.checkCancellation()
            guard tokenStore.token == token, let nextID = entries.last?.id else { return }
            let accepted = try await uploader.upload(entries)
            try Task.checkCancellation()
            guard tokenStore.token == token else { return }
            try await store.markUploaded(entries, acceptedIDs: accepted)
            afterID = nextID
        }
    }
}
