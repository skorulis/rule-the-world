import ASKCore
import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class HexVisitLogListViewModel {
    private(set) var entries: [HexVisitLog] = []
    private(set) var errorMessage: String?
    private let store: HexVisitLogStore
    private let syncService: HexVisitSyncService

    var pendingCount: Int { entries.filter { !$0.uploaded }.count }
    var syncedCount: Int { entries.filter(\.uploaded).count }
    var isSyncing: Bool { syncService.isSyncing }

    @Resolvable<Resolver>
    init(store: HexVisitLogStore, syncService: HexVisitSyncService) {
        self.store = store
        self.syncService = syncService
    }

    func observeEntries() async {
        do {
            try await store.observeEntries { entries in
                self.entries = entries
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func sync() async {
        guard !isSyncing else { return }
        errorMessage = nil
        do {
            try await syncService.syncPendingVisits()
            entries = try await store.all().reversed()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func clearSynced() async {
        do {
            try await store.deleteUploaded()
            entries = try await store.all().reversed()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func load() async {
        do {
            entries = try await store.all().reversed()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
