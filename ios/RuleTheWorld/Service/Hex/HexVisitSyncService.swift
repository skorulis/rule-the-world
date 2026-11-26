import Foundation
import OSLog
import Observation

@Observable
@MainActor
final class HexVisitSyncService {
    private let store: HexVisitLogStore
    private let hexInfoStore: HexInfoStore
    private let uploader: AuthenticatedService
    private let tokenStore: AuthTokenStore
    private let profileStore: ProfileSummaryStore?
    private let notificationService: NotificationService?
    private let titleNotifications: TitleNotificationBuilder
    private let waitForNextCheck: () async throws -> Void
    @ObservationIgnored private var syncRequests: AsyncStream<Void>.Continuation?
    private var runID: UUID?
    private var syncRequestedWhileBusy = false
    private(set) var isSyncing = false

    init(
        store: HexVisitLogStore,
        hexInfoStore: HexInfoStore,
        uploader: AuthenticatedService,
        tokenStore: AuthTokenStore,
        profileStore: ProfileSummaryStore? = nil,
        notificationService: NotificationService? = nil,
        titleNotifications: TitleNotificationBuilder = .init(catalog: RankCatalog(), regionNames: RegionNameCatalog()),
        waitForNextCheck: @escaping () async throws -> Void = { try await Task.sleep(for: .seconds(600)) }
    ) {
        self.store = store
        self.hexInfoStore = hexInfoStore
        self.uploader = uploader
        self.tokenStore = tokenStore
        self.profileStore = profileStore
        self.notificationService = notificationService
        self.titleNotifications = titleNotifications
        self.waitForNextCheck = waitForNextCheck
    }

    func requestImmediateSync() {
        syncRequests?.yield(())
    }

    func run() async {
        let id = UUID()
        let (requests, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        syncRequests?.finish()
        syncRequests = continuation
        runID = id
        var timer: Task<Void, Never>?
        defer {
            timer?.cancel()
            continuation.finish()
            if runID == id {
                syncRequests = nil
                runID = nil
            }
        }
        continuation.yield(())
        for await _ in requests {
            guard !Task.isCancelled, runID == id else { return }
            timer?.cancel()
            do {
                try await syncPendingVisits()
            } catch is CancellationError {
                return
            } catch {
                Logger().error("Visit upload failed; pending visits will be retried.")
            }
            guard !Task.isCancelled, runID == id else { return }
            timer = Task {
                do {
                    try Task.checkCancellation()
                    try await waitForNextCheck()
                    try Task.checkCancellation()
                    continuation.yield(())
                } catch {
                    if !Task.isCancelled { continuation.finish() }
                }
            }
        }
    }

    func syncPendingVisits() async throws {
        guard let token = tokenStore.token else { return }
        guard !isSyncing else {
            syncRequestedWhileBusy = true
            return
        }
        isSyncing = true
        defer {
            isSyncing = false
            if syncRequestedWhileBusy {
                syncRequestedWhileBusy = false
                requestImmediateSync()
            }
        }
        let lastID = try await store.latest()?.id ?? 0
        var afterID: Int64 = 0
        var previousRankings = profileStore?.summary?.rankings
        while afterID < lastID {
            try Task.checkCancellation()
            guard tokenStore.token == token else { return }
            let entries = try await store.pending(after: afterID, through: lastID)
            try Task.checkCancellation()
            guard tokenStore.token == token, let nextID = entries.last?.id else { return }
            if previousRankings == nil {
                previousRankings = try await rankingsBeforeUpload(token: token)
            }
            guard let response = try await upload(entries, token: token) else { return }
            applyRankings(response.rankings, previous: previousRankings)
            previousRankings = response.rankings
            afterID = nextID
        }
    }

    private func rankingsBeforeUpload(token: String) async throws -> [ProfileSummary.Ranking]? {
        guard notificationService != nil else { return nil }
        let summary = try await uploader.fetchProfile()
        try Task.checkCancellation()
        guard tokenStore.token == token else { return nil }
        profileStore?.save(summary)
        return summary.rankings
    }

    private func upload(_ entries: [HexVisitLog], token: String) async throws -> VisitBatchResponse? {
        try Task.checkCancellation()
        guard tokenStore.token == token else { return nil }
        let response = try await uploader.upload(entries)
        try Task.checkCancellation()
        guard tokenStore.token == token else { return nil }
        try await hexInfoStore.restore(response.hexInfos)
        try Task.checkCancellation()
        guard tokenStore.token == token else { return nil }
        try await store.markUploaded(entries, acceptedIDs: Set(response.acceptedIds))
        try Task.checkCancellation()
        return tokenStore.token == token ? response : nil
    }

    private func applyRankings(_ rankings: [ProfileSummary.Ranking], previous: [ProfileSummary.Ranking]?) {
        profileStore?.update(rankings: rankings)
        guard let previous, let notificationService else { return }
        for notification in titleNotifications.notifications(from: previous, to: rankings) {
            notificationService.show(notification)
        }
    }
}
