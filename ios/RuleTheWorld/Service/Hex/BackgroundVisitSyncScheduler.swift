import ASKCore
import BackgroundTasks
import Foundation
import OSLog
import UIKit

@MainActor
final class BackgroundVisitSyncScheduler {
    static let refreshTaskIdentifier = "com.skorulis.RuleTheWorld.visit-sync"
    static let minimumInterval: TimeInterval = 3600
    static let lastAttemptKey = "background-visit-sync-last-attempt"

    typealias BackgroundTimeRunner = @MainActor (@escaping @MainActor () async -> Void) async -> Void

    private let syncService: HexVisitSyncService
    private let store: HexVisitLogStore
    private let tokenStore: AuthTokenStore
    private let keyValueStore: PKeyValueStore
    private let now: @MainActor () -> Date
    private let submitRefresh: @MainActor (Date) throws -> Void
    private let withBackgroundTime: BackgroundTimeRunner

    init(
        syncService: HexVisitSyncService,
        store: HexVisitLogStore,
        tokenStore: AuthTokenStore,
        keyValueStore: PKeyValueStore,
        now: @escaping @MainActor () -> Date = { Date() },
        submitRefresh: @escaping @MainActor (Date) throws -> Void = BackgroundVisitSyncScheduler.submitAppRefresh,
        withBackgroundTime: @escaping BackgroundTimeRunner = BackgroundVisitSyncScheduler.runWithBackgroundTime
    ) {
        self.syncService = syncService
        self.store = store
        self.tokenStore = tokenStore
        self.keyValueStore = keyValueStore
        self.now = now
        self.submitRefresh = submitRefresh
        self.withBackgroundTime = withBackgroundTime
    }

    private var lastAttempt: Date {
        get { keyValueStore.date(forKey: Self.lastAttemptKey) ?? .distantPast }
        set { keyValueStore.set(date: newValue, forKey: Self.lastAttemptKey) }
    }

    func visitRecordedInBackground() {
        Task { await syncIfDue() }
    }

    func appDidEnterBackground() async {
        lastAttempt = max(lastAttempt, now())
        await scheduleRefreshIfNeeded()
    }

    func performRefresh() async {
        if tokenStore.token != nil, await hasPendingVisits() {
            await sync()
        }
        await scheduleRefreshIfNeeded()
    }

    func syncIfDue() async {
        guard tokenStore.token != nil,
              now() >= lastAttempt.addingTimeInterval(Self.minimumInterval),
              await hasPendingVisits() else { return }
        await sync()
        await scheduleRefreshIfNeeded()
    }

    private func sync() async {
        lastAttempt = now()
        await withBackgroundTime { [syncService] in
            do {
                try await syncService.syncPendingVisits()
            } catch is CancellationError {
                return
            } catch {
                Logger().error("Background visit upload failed; pending visits will be retried.")
            }
        }
    }

    private func scheduleRefreshIfNeeded() async {
        guard tokenStore.token != nil, await hasPendingVisits() else { return }
        do {
            try submitRefresh(max(now(), lastAttempt.addingTimeInterval(Self.minimumInterval)))
        } catch {
            Logger().error("Failed to schedule background visit sync: \(error)")
        }
    }

    private func hasPendingVisits() async -> Bool {
        (try? await store.pending(limit: 1).isEmpty == false) ?? false
    }

    static func submitAppRefresh(earliest: Date) throws {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskIdentifier)
        request.earliestBeginDate = earliest
        try BGTaskScheduler.shared.submit(request)
    }

    static func runWithBackgroundTime(_ operation: @escaping @MainActor () async -> Void) async {
        let application = UIApplication.shared
        let task = Task { await operation() }
        let backgroundTask = BackgroundTaskHandle()
        backgroundTask.identifier = application.beginBackgroundTask(withName: "VisitSync") {
            task.cancel()
            backgroundTask.end(in: application)
        }
        await task.value
        backgroundTask.end(in: application)
    }
}

@MainActor
private final class BackgroundTaskHandle {
    var identifier: UIBackgroundTaskIdentifier = .invalid

    func end(in application: UIApplication) {
        guard identifier != .invalid else { return }
        application.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
