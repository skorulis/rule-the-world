import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ShopViewModelTests {
    private let boxData = Data(#"""
        [{"id":1,"name":"Common Reward Box","cost":10,"rarity":"common"}]
        """#.utf8)

    private func makeModel(
        handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
    ) -> ShopViewModel {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("session-token")
        let service = AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession(handler: handler))
        let profileService = ProfileService(
            service: service, store: ProfileSummaryStore(keyValueStore: InMemoryKeyValueStore()))
        return ShopViewModel(
            service: service, profileService: profileService, lootBoxes: LootBoxCatalog(data: boxData))
    }

    private func ok(_ request: URLRequest, body: String) -> (Data, URLResponse) {
        (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }

    @Test func exposesCatalogBoxes() {
        let model = makeModel { _ in throw URLError(.notConnectedToInternet) }
        #expect(model.boxes.map(\.name) == ["Common Reward Box"])
        #expect(model.coins == nil)
    }

    @Test func loadPopulatesCoinBalance() async {
        let model = makeModel { request in
            #expect(request.url?.path == "/api/me")
            return ok(request, body: #"{"coins":42}"#)
        }
        await model.load()
        #expect(model.coins == 42)
    }

    @Test func purchaseUpdatesCoinsAndOpensRewards() async {
        let model = makeModel { request in
            ok(request, body: """
                {"rewards":[{"id":1,"type":"revisit","rarity":"common","bonus":1,"description":"+{bonus} score"}],"powerups":{"1":1},"coins":80}
                """)
        }
        let box = try #require(model.boxes.first)
        await model.purchase(box: box, count: 1)
        #expect(model.coins == 80)
        #expect(model.openedBox?.summary == "Common Revisit")
        #expect(model.errorMessage == nil)
    }

    @Test func purchaseAggregatesDuplicateRewards() async {
        let reward = #"{"id":1,"type":"revisit","rarity":"common","bonus":1,"description":"+{bonus} score"}"#
        let model = makeModel { request in
            ok(request, body: #"{"rewards":[\#(reward),\#(reward)],"powerups":{"1":2},"coins":0}"#)
        }
        let box = try #require(model.boxes.first)
        await model.purchase(box: box, count: 2)
        #expect(model.openedBox?.summary == "Common Revisit ×2")
    }

    @Test func insufficientFundsDisablesButtons() async {
        let model = makeModel { request in ok(request, body: #"{"coins":15}"#) }
        await model.load()
        let box = try #require(model.boxes.first)
        #expect(model.canAfford(box, count: 1))
        #expect(!model.canAfford(box, count: 5))
    }

    @Test func serverErrorBecomesMessage() async {
        let model = makeModel { request in
            (Data(#"{"error":"Not enough coins"}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 409, httpVersion: nil, headerFields: nil)!)
        }
        let box = try #require(model.boxes.first)
        await model.purchase(box: box, count: 1)
        #expect(model.errorMessage == "Not enough coins")
        #expect(model.openedBox == nil)
    }
}
