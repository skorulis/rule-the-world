import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ProfileViewModelTests {
    private func makeModel(
        values: PKeyValueStore = InMemoryKeyValueStore(),
        handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
    ) throws -> (ProfileViewModel, AuthManager) {
        let database = try AppDatabase.inMemory()
        let store = HexInfoStore(database: database)
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokenStore.save("session-token")
        let session = FakeURLSession(handler: handler)
        let service = AuthenticatedService(tokenStore: tokenStore, urlSession: session)
        let manager = AuthManager(
            service: AuthService(urlSession: session),
            authenticatedService: service,
            tokenStore: tokenStore,
            database: database,
            visitStore: store,
            profileStore: ProfileSummaryStore(keyValueStore: values)
        )
        let profileService = ProfileService(
            service: service, store: ProfileSummaryStore(keyValueStore: values))
        let model = ProfileViewModel(
            authManager: manager, service: service, profileService: profileService,
            bannerStore: BannerStore(keyValueStore: values))
        return (model, manager)
    }

    @Test func startsWithoutInventedCounts() throws {
        let (model, _) = try makeModel { _ in throw URLError(.notConnectedToInternet) }
        #expect(model.visitedHexCount == nil)
        #expect(model.ownedHexCount == nil)
    }

    @Test func loadsServerTotals() async throws {
        let (model, _) = try makeModel { request in
            #expect(request.url?.path == "/api/me")
            return (Data(#"{"visited":25,"owned":8}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await model.load()
        #expect(model.visitedHexCount == 25)
        #expect(model.ownedHexCount == 8)
    }

    @Test func refreshesAndRetainsLastSuccessOnFailure() async throws {
        let replies = Replies()
        let (model, _) = try makeModel { request in
            let body = try await replies.next()
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        }
        await model.load()
        #expect(model.visitedHexCount == 10)
        await model.load()
        #expect(model.visitedHexCount == 20)
        #expect(model.ownedHexCount == 7)
        await model.load()
        #expect(model.visitedHexCount == 20)
        #expect(model.ownedHexCount == 7)
    }

    @Test func cancelledLoadDoesNotPublishData() async throws {
        let (model, _) = try makeModel { request in
            withUnsafeCurrentTask { $0?.cancel() }
            return (Data(#"{"visited":10,"owned":5}"#.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        let task = Task { await model.load() }
        await task.value
        #expect(model.visitedHexCount == nil)
        #expect(model.ownedHexCount == nil)
    }

    @Test func countsUniqueTitlesMatchingTheTitlesScreen() async throws {
        let (model, _) = try makeModel { request in
            (Data("""
                {"rankings":[
                {"id":1,"type":"country","number":1},
                {"id":1,"type":"country","number":2},
                {"id":1,"type":"state","number":3},
                {"id":99,"type":"suburb","number":4},
                {"id":0,"type":"country","number":1},
                {"id":2,"type":"country","number":0}]}
                """.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        #expect(model.titleCount == nil)
        await model.load()
        #expect(model.titleCount == 3)
    }

    @Test func loadsZeroTitlesWhenRankingsAreEmpty() async throws {
        let (model, _) = try makeModel { request in
            (Data(#"{"rankings":[]}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await model.load()
        #expect(model.titleCount == 0)
    }

    @Test func forwardsDailyRewardAvailabilityToTheDailyRewardModel() async throws {
        let (model, _) = try makeModel { request in
            (Data(#"{"visited":1,"owned":0,"dailyRewardAvailableAt":"2026-11-24T00:00:00.000Z"}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        #expect(model.dailyReward.availableAt == nil)
        await model.load()
        #expect(model.dailyReward.availableAt == Date(timeIntervalSince1970: 1_795_478_400))
    }

    @Test func applyInventoryRefreshesPowerUpCountIgnoringInvalidEntries() throws {
        let (model, _) = try makeModel { _ in throw URLError(.notConnectedToInternet) }
        model.applyInventory(["1": 2, "4": 1, "0": 5, "x": 3, "5": -1])
        #expect(model.powerUpCount == 3)
    }

    @Test func signOutStillClearsAuthentication() throws {
        let (model, manager) = try makeModel { _ in throw URLError(.unsupportedURL) }
        #expect(manager.isSignedIn)
        model.signOut()
        #expect(!manager.isSignedIn)
    }

    @Test func cachedIdentityLoadsSavedBannerOfflineAndRefreshesAfterEditing() async throws {
        let values = InMemoryKeyValueStore()
        let summary = try JSONDecoder().decode(
            ProfileSummary.self, from: Data(#"{"user":{"id":"alice","name":"Alice"}}"#.utf8))
        ProfileSummaryStore(keyValueStore: values).save(summary)
        let banners = BannerStore(keyValueStore: values)
        var banner = BannerConfiguration.default
        banner.emblem = .sword
        try banners.save(banner, for: "alice")
        let (model, _) = try makeModel(values: values) { _ in throw URLError(.notConnectedToInternet) }
        await model.load()
        #expect(model.userID == "alice")
        #expect(model.canEditBanner)
        #expect(model.banner == banner)
        banner.backgroundColor = .crimson
        try banners.save(banner, for: "alice")
        model.refreshBanner()
        #expect(model.banner == banner)
        await model.load()
        #expect(model.banner == banner)
    }

    @Test func signOutClearsProfileCacheButPreservesAccountBanner() async throws {
        let values = InMemoryKeyValueStore()
        let summary = try JSONDecoder().decode(
            ProfileSummary.self, from: Data(#"{"user":{"id":"alice"}}"#.utf8))
        let profiles = ProfileSummaryStore(keyValueStore: values)
        profiles.save(summary)
        let banners = BannerStore(keyValueStore: values)
        var banner = BannerConfiguration.default
        banner.emblem = .crown
        try banners.save(banner, for: "alice")
        let (model, _) = try makeModel(values: values) { _ in throw URLError(.notConnectedToInternet) }
        await model.load()
        model.signOut()
        #expect(profiles.summary == nil)
        #expect(banners.banner(for: "alice") == banner)
        #expect(banners.banner(for: "bob") == .default)
    }

    @Test func profileWithoutIdentityCannotEditBanner() async throws {
        let (model, _) = try makeModel { request in
            (Data(#"{"user":{"name":"Legacy"}}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await model.load()
        #expect(model.userID == nil)
        #expect(!model.canEditBanner)
        #expect(model.banner == .default)
    }

    @Test func fetchedIdentityDoesNotUseAnotherAccountsBanner() async throws {
        let values = InMemoryKeyValueStore()
        var banner = BannerConfiguration.default
        banner.emblem = .shield
        try BannerStore(keyValueStore: values).save(banner, for: "alice")
        let (model, _) = try makeModel(values: values) { request in
            (Data(#"{"user":{"id":"bob","name":"Bob"}}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        await model.load()
        #expect(model.userID == "bob")
        #expect(model.banner == .default)
        #expect(model.canEditBanner)
    }

    private actor Replies {
        private var count = 0

        func next() throws -> String {
            count += 1
            switch count {
            case 1: return #"{"visited":10,"owned":5}"#
            case 2: return #"{"visited":20,"owned":7}"#
            default: throw URLError(.notConnectedToInternet)
            }
        }
    }
}
