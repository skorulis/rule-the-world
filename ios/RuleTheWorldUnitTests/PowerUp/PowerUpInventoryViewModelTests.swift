import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct PowerUpInventoryViewModelTests {
    private let catalogData = Data(#"""
        [
          {"id":1,"type":"revisit","rarity":"common","bonus":1,"description":"+{bonus} score"},
          {"id":2,"type":"revisit","rarity":"rare","bonus":2,"description":"+{bonus} score"},
          {"id":3,"type":"revisit","rarity":"epic","bonus":3,"description":"+{bonus} score"},
          {"id":6,"type":"attack","rarity":"common","bonus":1,"description":"+{bonus} score"}
        ]
        """#.utf8)

    private let sample = LocationSample(
        latitude: -33.89, longitude: 151.19, speed: nil, course: nil,
        horizontalAccuracy: 10, timestamp: Date()
    )

    private func makeStore() throws -> HexInfoStore {
        try HexInfoStore(database: AppDatabase.inMemory())
    }

    private func makeModel(
        body: String,
        consumeStatus: Int = 200,
        consumeBody: String = #"{"powerups":{},"visits":[]}"#,
        onConsumeRequest: @escaping (URLRequest) -> Void = { _ in }
    ) throws -> PowerUpInventoryViewModel {
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokenStore.save("session-token")
        let session = FakeURLSession { request in
            let path = request.url?.path
            let status = path == "/api/powerup/consume" ? consumeStatus : 200
            if path == "/api/powerup/consume" { onConsumeRequest(request) }
            let responseBody = path == "/api/me" ? body : consumeBody
            return (Data(responseBody.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        return PowerUpInventoryViewModel(
            service: AuthenticatedService(tokenStore: tokenStore, urlSession: session),
            catalog: PowerUpCatalog(data: catalogData),
            locationService: LocationService(),
            store: try makeStore()
        )
    }

    @Test func sortsByRarityThenNameAndResolvesDefinitions() async throws {
        let model = try makeModel(body: #"{"powerups":{"3":1,"1":4,"2":2}}"#)
        await model.load()
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(model.items.map(\.count) == [4, 2, 1])
        #expect(model.items.first?.name == "Common Revisit")
        #expect(model.items.last?.detail == "+3 score")
    }

    @Test func unknownIdsSortLastWithFallbackName() async throws {
        let model = try makeModel(body: #"{"powerups":{"99":1,"1":1}}"#)
        await model.load()
        #expect(model.items.map(\.id) == [1, 99])
        #expect(model.items.last?.name == "Unknown power-up #99")
        #expect(model.items.last?.rarity == nil)
    }

    @Test func emptyInventoryAndFailuresYieldNoItems() async throws {
        let model = try makeModel(body: #"{"visited":5}"#)
        await model.load()
        #expect(model.items.isEmpty)
        let failing = PowerUpInventoryViewModel(
            service: AuthenticatedService(
                tokenStore: AuthTokenStore(keyValueStore: InMemoryKeyValueStore()),
                urlSession: FakeURLSession { _ in throw URLError(.notConnectedToInternet) }
            ),
            catalog: PowerUpCatalog(data: catalogData),
            locationService: LocationService(),
            store: try makeStore()
        )
        await failing.load()
        #expect(failing.items.isEmpty)
    }

    @Test func consumeSendsPowerUpAndLocationThenUpdatesInventory() async throws {
        var captured: URLRequest?
        let model = try makeModel(
            body: #"{"powerups":{"1":2}}"#,
            consumeBody: #"{"powerups":{"1":1},"visits":[{"totals":{"totalVisits":4,"rivalScore":0},"userVisit":{"cell":"8a2830828767fff","lastVisit":"2026-11-20T10:00:00Z","score":6,"lastScore":0.5,"total":2}}]}"#,
            onConsumeRequest: { captured = $0 }
        )
        await model.load()
        let item = try #require(model.items.first)

        await model.consume(item: item, location: sample)

        #expect(captured?.url?.path == "/api/powerup/consume")
        let sent = try #require(captured?.httpBody)
        let payload = try JSONSerialization.jsonObject(with: sent) as? [String: Any]
        #expect(payload?["powerup"] as? Int == 1)
        let location = payload?["location"] as? [String: Any]
        #expect(location?["latitude"] as? Double == -33.89)
        #expect(location?["longitude"] as? Double == 151.19)
        #expect(model.items.map(\.count) == [1])
        #expect(model.message == "Common Revisit applied.")
        #expect(model.isConsuming == false)
    }

    @Test func consumeRemovesExhaustedItems() async throws {
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            consumeBody: #"{"powerups":{},"visits":[{"totals":{"totalVisits":1,"rivalScore":0},"userVisit":{"cell":"8a2830828767fff","lastVisit":"2026-11-20T10:00:00Z","score":3,"lastScore":0,"total":1}}]}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first), location: sample)
        #expect(model.items.isEmpty)
    }

    @Test func consumeWithoutLocationReportsMessage() async throws {
        let model = try makeModel(body: #"{"powerups":{"1":1}}"#)
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(model.message?.contains("Location unavailable") == true)
        #expect(model.items.map(\.count) == [1])
    }

    @Test func attackWithoutTargetShowsServerErrorAndLeavesInventory() async throws {
        let message = "No squares in range where you already have a score and someone else owns it. Your Attack power-up was not consumed."
        let model = try makeModel(
            body: #"{"powerups":{"6":1}}"#,
            consumeStatus: 404,
            consumeBody: #"{"error":"No squares in range where you already have a score and someone else owns it. Your Attack power-up was not consumed."}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first), location: sample)
        #expect(model.items.map(\.count) == [1])
        #expect(model.message == message)
        #expect(model.isConsuming == false)
    }

    @Test func consumeFailureLeavesInventory() async throws {
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            consumeStatus: 500,
            consumeBody: #"{"error":"Unable to consume power-up"}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first), location: sample)
        #expect(model.items.map(\.count) == [1])
        #expect(model.message == "Unable to consume power-up")
    }
}
