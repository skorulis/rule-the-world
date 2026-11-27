import ASKCore
import CoreLocation
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
final class BackgroundSyncHarness {
    let store: HexVisitLogStore
    let uploader = VisitUploadSession()
    let tokens: AuthTokenStore
    var now = Date(timeIntervalSince1970: 1_800_000_000)
    var refreshDates: [Date] = []
    var backgroundTimeRequests = 0
    lazy var scheduler = BackgroundVisitSyncScheduler(
        syncService: HexVisitSyncService(
            store: store,
            hexInfoStore: HexInfoStore(database: database),
            uploader: uploader.service,
            tokenStore: tokens
        ),
        store: store,
        tokenStore: tokens,
        keyValueStore: InMemoryKeyValueStore(),
        now: { [unowned self] in now },
        submitRefresh: { [unowned self] in refreshDates.append($0) },
        withBackgroundTime: { [unowned self] operation in
            backgroundTimeRequests += 1
            await operation()
        }
    )
    private let database: AppDatabase

    init() throws {
        database = try AppDatabase.inMemory()
        store = HexVisitLogStore(database: database)
        tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("token")
    }

    func recordVisit(latitude: Double = -33.89) async throws {
        _ = try await store.record(HexVisitLog(
            timestamp: now, cell: HexGridService().cell(
                containing: .init(latitude: latitude, longitude: 151.19),
                resolution: HexGridService.baseResolution
            ),
            latitude: latitude, longitude: 151.19, speed: 1, score: 1
        ))
    }
}

@MainActor
struct BackgroundVisitSyncSchedulerTests {
    @Test func backgroundVisitUploadsPendingVisitsWithBackgroundTime() async throws {
        let harness = try BackgroundSyncHarness()
        try await harness.recordVisit()
        await harness.scheduler.syncIfDue()
        #expect(harness.uploader.calls.count == 1)
        #expect(harness.backgroundTimeRequests == 1)
        #expect(try await harness.store.pending().isEmpty)
        #expect(harness.refreshDates.isEmpty)
    }

    @Test func backgroundVisitsAreThrottledToOncePerHour() async throws {
        let harness = try BackgroundSyncHarness()
        try await harness.recordVisit()
        await harness.scheduler.syncIfDue()
        harness.now.addTimeInterval(BackgroundVisitSyncScheduler.minimumInterval - 1)
        try await harness.recordVisit(latitude: -33.95)
        await harness.scheduler.syncIfDue()
        #expect(harness.uploader.calls.count == 1)
        harness.now.addTimeInterval(1)
        await harness.scheduler.syncIfDue()
        #expect(harness.uploader.calls.count == 2)
        #expect(try await harness.store.pending().isEmpty)
    }

    @Test func nothingPendingDoesNotSyncOrSchedule() async throws {
        let harness = try BackgroundSyncHarness()
        await harness.scheduler.syncIfDue()
        await harness.scheduler.appDidEnterBackground()
        await harness.scheduler.performRefresh()
        #expect(harness.uploader.calls.isEmpty)
        #expect(harness.backgroundTimeRequests == 0)
        #expect(harness.refreshDates.isEmpty)
    }

    @Test func signedOutDoesNotSyncOrSchedule() async throws {
        let harness = try BackgroundSyncHarness()
        try await harness.recordVisit()
        harness.tokens.clear()
        await harness.scheduler.syncIfDue()
        await harness.scheduler.appDidEnterBackground()
        await harness.scheduler.performRefresh()
        #expect(harness.uploader.calls.isEmpty)
        #expect(harness.refreshDates.isEmpty)
        #expect(try await harness.store.pending().count == 1)
    }

    @Test func enteringBackgroundWithPendingVisitsSchedulesRefreshAnHourLater() async throws {
        let harness = try BackgroundSyncHarness()
        try await harness.recordVisit()
        await harness.scheduler.appDidEnterBackground()
        #expect(harness.refreshDates == [harness.now.addingTimeInterval(BackgroundVisitSyncScheduler.minimumInterval)])
        #expect(harness.uploader.calls.isEmpty)
        await harness.scheduler.syncIfDue()
        #expect(harness.uploader.calls.isEmpty)
    }

    @Test func failedRefreshKeepsVisitsPendingAndReschedules() async throws {
        let harness = try BackgroundSyncHarness()
        try await harness.recordVisit()
        harness.uploader.handler = { _ in throw URLError(.notConnectedToInternet) }
        await harness.scheduler.performRefresh()
        #expect(harness.uploader.calls.count == 1)
        #expect(try await harness.store.pending().count == 1)
        #expect(harness.refreshDates == [harness.now.addingTimeInterval(BackgroundVisitSyncScheduler.minimumInterval)])
    }

    @Test func successfulRefreshDoesNotReschedule() async throws {
        let harness = try BackgroundSyncHarness()
        try await harness.recordVisit()
        await harness.scheduler.performRefresh()
        #expect(harness.uploader.calls.count == 1)
        #expect(harness.refreshDates.isEmpty)
    }
}
