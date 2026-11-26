import ASKCoordinator
import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

extension HexVisitSyncServiceTests {
    @Test func successfulSyncQueuesTitlePromotionOnlyOnce() async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        uploader.rankings = [ProfileSummary.Ranking(id: 7, type: "country", number: 1, visited: 5, owned: 3)]
        let profile = ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())
        profile.save(try JSONDecoder().decode(
            ProfileSummary.self, from: Data(#"{"rankings":[{"id":7,"type":"country","number":15}]}"#.utf8)
        ))
        var notifications: [AppNotification] = []
        var presentationSession = UUID()
        let notificationService = NotificationService { _, notification, session in
            notifications.append(notification)
            presentationSession = session
        }
        let host = Coordinator(root: MainPath.hexMap)
        notificationService.attach(to: host)
        let sync = HexVisitSyncService(
            store: store, hexInfoStore: HexInfoStore(database: try AppDatabase.inMemory()),
            uploader: uploader.service, tokenStore: tokenStore(), profileStore: profile,
            notificationService: notificationService
        )
        try await sync.syncPendingVisits()
        #expect(notifications.count == 1)
        #expect(notifications.first?.title == "New title!")
        #expect(profile.summary?.rankings.first?.number == 1)
        notificationService.didDismiss(id: try #require(notifications.first).id, sessionID: presentationSession)
        _ = try await store.record(entry(cell: 0x8A283082872FFFF))
        try await sync.syncPendingVisits()
        #expect(notifications.count == 1)
        #expect(notificationService.activeNotificationID == nil)
    }

    @Test(arguments: [true, false])
    func failedOrChangedSessionDoesNotAnnounceTitles(changedSession: Bool) async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        uploader.rankings = [ProfileSummary.Ranking(id: 7, type: "country", number: 1, visited: 5, owned: 3)]
        let tokens = tokenStore()
        let profile = ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())
        profile.save(try JSONDecoder().decode(ProfileSummary.self, from: Data(#"{"rankings":[]}"#.utf8)))
        var notifications: [AppNotification] = []
        let service = NotificationService { _, notification, _ in notifications.append(notification) }
        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        uploader.handler = { entries in
            if !changedSession { throw URLError(.notConnectedToInternet) }
            tokens.save("different-session")
            return Set(entries.map(\.uploadID))
        }
        let sync = HexVisitSyncService(
            store: store, hexInfoStore: HexInfoStore(database: try AppDatabase.inMemory()),
            uploader: uploader.service, tokenStore: tokens, profileStore: profile, notificationService: service
        )
        if changedSession {
            try await sync.syncPendingVisits()
        } else {
            await #expect(throws: URLError.self) { try await sync.syncPendingVisits() }
        }
        #expect(notifications.isEmpty)
        #expect(profile.summary?.rankings.isEmpty == true)
        #expect(try await store.pending().count == 1)
    }

    @Test(arguments: [true, false])
    func missingProfileLoadsBaselineBeforeAnnouncingTitles(hasExistingTitle: Bool) async throws {
        let store = HexVisitLogStore(database: try AppDatabase.inMemory())
        _ = try await store.record(entry())
        let uploader = VisitUploadSession()
        if hasExistingTitle {
            uploader.profileData = Data(#"{"rankings":[{"id":7,"type":"country","number":1}]}"#.utf8)
        }
        uploader.rankings = [ProfileSummary.Ranking(id: 7, type: "country", number: 1, visited: 5, owned: 3)]
        let profile = ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())
        var notifications: [AppNotification] = []
        let service = NotificationService { _, notification, _ in notifications.append(notification) }
        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        let sync = HexVisitSyncService(
            store: store, hexInfoStore: HexInfoStore(database: try AppDatabase.inMemory()),
            uploader: uploader.service, tokenStore: tokenStore(), profileStore: profile, notificationService: service
        )
        try await sync.syncPendingVisits()
        #expect(uploader.profileRequests == 1)
        #expect(notifications.count == (hasExistingTitle ? 0 : 1))
        #expect(profile.summary?.rankings.first?.number == 1)
    }
}
