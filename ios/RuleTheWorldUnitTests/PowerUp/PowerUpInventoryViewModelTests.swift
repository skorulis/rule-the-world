import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct PowerUpInventoryViewModelTests {
    private let catalogData = Data(#"""
        [
          {"id":1,"type":"attack","rarity":"common","bonus":1,"squares":3,"description":"+{bonus} score to up to {squares} squares"},
          {"id":2,"type":"attack","rarity":"rare","bonus":2,"squares":5,"description":"+{bonus} score to up to {squares} squares"},
          {"id":3,"type":"defend","rarity":"common","bonus":1,"squares":3,"description":"+{bonus} score to up to {squares} squares"},
          {"id":4,"type":"defend","rarity":"rare","bonus":2,"squares":5,"description":"+{bonus} score to up to {squares} squares"},
          {"id":5,"type":"explore","rarity":"common","bonus":1,"squares":3,"description":"+{bonus} score to up to {squares} squares"},
          {"id":6,"type":"explore","rarity":"rare","bonus":2,"squares":5,"description":"+{bonus} score to up to {squares} squares"}
        ]
        """#.utf8)

    private let rivalOwnedCell = HexCell(rawValue: 0x8a2830828767fff)
    private let ownedCell = HexCell(rawValue: 0x8a2830828760fff)
    private let unvisitedCell = HexCell(rawValue: 0x8a2830828712fff)
    private let window = [HexCell(rawValue: 0x8a2830828767fff),
                          HexCell(rawValue: 0x8a2830828760fff),
                          HexCell(rawValue: 0x8a2830828712fff)]

    private func makeStore() throws -> HexInfoStore {
        try HexInfoStore(database: AppDatabase.inMemory())
    }

    private func seedStore(_ store: HexInfoStore) async throws {
        try await store.restore([
            HexInfo(cell: rivalOwnedCell,
                    totals: HexTotals(totalVisits: 3, rivalScore: 4),
                    userVisit: HexVisit(lastVisit: .distantPast, score: 2, lastScore: 0, total: 2)),
            HexInfo(cell: ownedCell,
                    totals: HexTotals(totalVisits: 4, rivalScore: 1),
                    userVisit: HexVisit(lastVisit: .distantPast, score: 5, lastScore: 0, total: 4)),
            HexInfo(cell: unvisitedCell,
                    totals: HexTotals(totalVisits: 2, rivalScore: 3),
                    userVisit: nil),
        ])
    }

    private func makeModel(
        body: String,
        seededBody: String? = nil,
        profileFails: Bool = false,
        consumeStatus: Int = 200,
        consumeBody: String = #"{"powerups":{},"visits":[]}"#,
        store: HexInfoStore? = nil,
        onConsumeRequest: @escaping (URLRequest) -> Void = { _ in }
    ) throws -> PowerUpInventoryViewModel {
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokenStore.save("session-token")
        let session = FakeURLSession { request in
            let path = request.url?.path
            if path == "/api/me", profileFails { throw URLError(.notConnectedToInternet) }
            let status = path == "/api/powerup/consume" ? consumeStatus : 200
            if path == "/api/powerup/consume" { onConsumeRequest(request) }
            let responseBody = path == "/api/me" ? body : consumeBody
            return (Data(responseBody.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        }
        let service = AuthenticatedService(tokenStore: tokenStore, urlSession: session)
        let summaryStore = ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())
        if let seededBody,
           let summary = try? JSONDecoder().decode(ProfileSummary.self, from: Data(seededBody.utf8)) {
            summaryStore.save(summary)
        }
        let model = PowerUpInventoryViewModel(
            service: service,
            profileService: ProfileService(service: service, store: summaryStore),
            catalog: PowerUpCatalog(data: catalogData),
            store: try store ?? makeStore()
        )
        model.mapWindowProvider = { self.window }
        model.mapIsAtHexResolution = true
        return model
    }

    private func sentCells(_ request: URLRequest?) throws -> [String] {
        let payload = try #require(request?.httpBody)
        let body = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        return try #require(body?["cells"] as? [String])
    }

    @Test func sortsByRarityThenNameAndResolvesDefinitions() async throws {
        let model = try makeModel(body: #"{"powerups":{"5":1,"1":4,"2":2}}"#)
        await model.load()
        #expect(model.items.map(\.id) == [1, 5, 2])
        #expect(model.items.map(\.count) == [4, 1, 2])
        #expect(model.totalCount == 7)
        #expect(model.items.first?.name == "Common Attack")
        #expect(model.items.last?.detail == "+2 score to up to 5 squares")
    }

    @Test func unknownIdsAreHidden() async throws {
        let model = try makeModel(body: #"{"powerups":{"99":1,"1":1}}"#)
        await model.load()
        #expect(model.items.map(\.id) == [1])
    }

    @Test func cachedSummaryPopulatesItemsWhenFetchFails() async throws {
        let model = try makeModel(
            body: "{}", seededBody: #"{"powerups":{"1":4,"2":2}}"#, profileFails: true)
        await model.load()
        #expect(model.items.map(\.id) == [1, 2])
        #expect(model.items.map(\.count) == [4, 2])
        #expect(model.totalCount == 6)
    }

    @Test func emptyInventoryAndFailuresYieldNoItems() async throws {
        let model = try makeModel(body: #"{"visited":5}"#)
        await model.load()
        #expect(model.items.isEmpty)
        #expect(model.totalCount == 0)
        let failingService = AuthenticatedService(
            tokenStore: AuthTokenStore(keyValueStore: InMemoryKeyValueStore()),
            urlSession: FakeURLSession { _ in throw URLError(.notConnectedToInternet) }
        )
        let failing = PowerUpInventoryViewModel(
            service: failingService,
            profileService: ProfileService(
                service: failingService, store: ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore())),
            catalog: PowerUpCatalog(data: catalogData),
            store: try makeStore()
        )
        await failing.load()
        #expect(failing.items.isEmpty)
    }

    @Test func consumeSendsViableCellsAndUpdatesInventory() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var captured: URLRequest?
        let model = try makeModel(
            body: #"{"powerups":{"1":2}}"#,
            store: store,
            consumeBody: #"{"powerups":{"1":1},"visits":[]}"#,
            onConsumeRequest: { captured = $0 }
        )
        await model.load()
        let item = try #require(model.items.first)

        await model.consume(item: item)

        #expect(captured?.url?.path == "/api/powerup/consume")
        let payload = try #require(captured?.httpBody)
        #expect((try JSONSerialization.jsonObject(with: payload) as? [String: Any])?["powerup"] as? Int == 1)
        // Common Attack wants 3 squares but only 2 qualify (rival-owned and
        // the unvisited-but-rival-scored hex), so the power-up applies to both.
        #expect(try Set(sentCells(captured)) == Set([rivalOwnedCell, unvisitedCell].map(\.description)))
        #expect(model.items.map(\.count) == [1])
        #expect(model.message == "Common Attack applied to 2 squares.")
        #expect(model.isConsuming == false)
    }

    @Test func defendAndExplorePickTheRightCells() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var captured: [URLRequest] = []
        let model = try makeModel(
            body: #"{"powerups":{"3":1,"5":1}}"#,
            store: store,
            consumeBody: #"{"powerups":{},"visits":[]}"#,
            onConsumeRequest: { captured.append($0) }
        )
        await model.load()
        await model.consume(item: try #require(model.items.first { $0.id == 3 }))
        await model.consume(item: try #require(model.items.first { $0.id == 5 }))
        #expect(try sentCells(captured[0]) == [ownedCell.description])
        #expect(try sentCells(captured[1]) == [unvisitedCell.description])
    }

    @Test func consumeRemovesExhaustedItems() async throws {
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            store: store,
            consumeBody: #"{"powerups":{},"visits":[]}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(model.items.isEmpty)
        #expect(model.totalCount == 0)
    }

    @Test func consumeWithoutHexResolutionRefuses() async throws {
        var captured: URLRequest?
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            onConsumeRequest: { captured = $0 }
        )
        model.mapWindowProvider = { nil }
        model.mapIsAtHexResolution = false
        await model.load()
        #expect(model.canUse == false)
        await model.consume(item: try #require(model.items.first))
        #expect(model.message?.contains("Zoom in") == true)
        #expect(model.items.map(\.count) == [1])
        #expect(captured == nil)
    }

    @Test func consumeWithoutViableCellsRefuses() async throws {
        var captured: URLRequest?
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(
            body: #"{"powerups":{"3":1}}"#,
            store: store,
            onConsumeRequest: { captured = $0 }
        )
        model.mapWindowProvider = { [self.rivalOwnedCell, self.unvisitedCell] }
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(model.message == "No viable squares in view — Common Defend was not used.")
        #expect(model.items.map(\.count) == [1])
        #expect(captured == nil)
    }

    @Test func consumeAppliesOptimisticallyThenRestoresServerScores() async throws {
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            store: store,
            consumeBody: #"{"powerups":{},"visits":[{"totals":{"totalVisits":3,"rivalScore":4},"userVisit":{"cell":"8a2830828767fff","lastVisit":"2026-11-20T10:00:00Z","score":10,"lastScore":0.5,"total":2}}]}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first))
        let info = try await store.info(for: rivalOwnedCell)
        // Optimistic bump would have been 3; the server's authoritative 10 wins.
        #expect(info?.userVisit?.score == 10)
    }

    @Test func consumeFailureRollsBackOptimisticScores() async throws {
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            store: store,
            consumeStatus: 500,
            consumeBody: #"{"error":"Unable to consume power-up"}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(model.items.map(\.count) == [1])
        #expect(model.message == "Unable to consume power-up")
        let info = try await store.info(for: rivalOwnedCell)
        #expect(info?.userVisit?.score == 2)
        let unvisited = try await store.info(for: unvisitedCell)
        #expect(unvisited?.userVisit == nil)
    }
}

extension PowerUpInventoryViewModelTests {
    @Test func selectionResolvesCurrentInventoryAndClearsWhenExhausted() async throws {
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(body: #"{"powerups":{"1":1}}"#, store: store)
        await model.load()
        model.selectedItemID = 1
        #expect(model.selectedItem?.count == 1)

        await model.consumeSelected()

        #expect(model.selectedItem == nil)
        #expect(model.selectedItemID == nil)
        #expect(model.message == "Common Attack applied to 2 squares.")
        #expect(model.activatedItemID == 1)
    }

    @Test func refreshClearsMissingSelection() async throws {
        let model = try makeModel(body: #"{"powerups":{"1":2}}"#)
        model.selectedItemID = 99
        await model.load()
        #expect(model.selectedItemID == nil)
        model.selectedItemID = 1
        await model.load()
        #expect(model.selectedItem?.count == 2)
    }

    @Test func zeroCountInventoryCannotRemainSelected() async throws {
        let model = try makeModel(body: #"{"powerups":{"1":0}}"#)
        model.selectedItemID = 1
        await model.load()
        #expect(model.items.isEmpty)
        #expect(model.selectedItemID == nil)
    }

    @Test func staleItemCannotBeConsumedAgain() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var requests = 0
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#, store: store,
            onConsumeRequest: { _ in requests += 1 }
        )
        await model.load()
        let staleItem = try #require(model.items.first)
        await model.consume(item: staleItem)
        await model.consume(item: staleItem)
        #expect(requests == 1)
    }

    @Test func repeatedSuccessProducesDistinctFeedback() async throws {
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(
            body: #"{"powerups":{"1":2}}"#, store: store,
            consumeBody: #"{"powerups":{"1":1},"visits":[]}"#
        )
        await model.load()
        model.selectedItemID = 1
        let initial = model.activationID
        await model.consumeSelected()
        let first = model.activationID
        await model.consumeSelected()
        #expect(initial != first)
        #expect(first != model.activationID)
        #expect(model.selectedItem?.count == 1)
    }

    @Test func concurrentUseOnlySendsOneRequest() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var requests = 0
        let model = try makeModel(
            body: #"{"powerups":{"1":2}}"#, store: store,
            consumeBody: #"{"powerups":{"1":1},"visits":[]}"#,
            onConsumeRequest: { _ in requests += 1 }
        )
        await model.load()
        model.selectedItemID = 1
        let first = Task { await model.consumeSelected() }
        let second = Task { await model.consumeSelected() }
        await first.value
        await second.value
        #expect(requests == 1)
        #expect(!model.isConsuming)
    }

    @Test func newAttemptReplacesOldMessageWithoutSuccessFeedbackOnFailure() async throws {
        let store = try makeStore()
        try await seedStore(store)
        var model: PowerUpInventoryViewModel?
        var messageAtRequest: String? = "Not requested"
        let inventory = try makeModel(
            body: #"{"powerups":{"1":1}}"#, store: store,
            consumeStatus: 500, consumeBody: #"{"error":"Try again later"}"#,
            onConsumeRequest: { _ in messageAtRequest = model?.message }
        )
        model = inventory
        defer { model = nil }
        await inventory.load()
        inventory.selectedItemID = 1
        inventory.mapWindowProvider = { nil }
        await inventory.consumeSelected()
        #expect(inventory.message?.contains("Zoom in") == true)
        let initial = inventory.activationID
        inventory.mapWindowProvider = { self.window }
        await inventory.consumeSelected()
        #expect(messageAtRequest == nil)
        #expect(inventory.message == "Try again later")
        #expect(inventory.activationID == initial)
        #expect(inventory.activatedItemID == nil)
        #expect(inventory.selectedItemID == 1)
    }

    @Test func serverErrorLeavesInventory() async throws {
        let store = try makeStore()
        try await seedStore(store)
        let model = try makeModel(
            body: #"{"powerups":{"1":1}}"#,
            store: store,
            consumeStatus: 400,
            consumeBody: #"{"error":"Power-up not in inventory"}"#
        )
        await model.load()
        await model.consume(item: try #require(model.items.first))
        #expect(model.items.map(\.count) == [1])
        #expect(model.message == "Power-up not in inventory")
        #expect(model.isConsuming == false)
    }
}
