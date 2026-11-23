import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct PowerUpInventoryViewModelTests {
    private let catalogData = Data(#"""
        [
          {"id":1,"type":"revisit","rarity":"common","bonus":1,"name":"Common Revisit","description":"+{bonus} score"},
          {"id":2,"type":"revisit","rarity":"rare","bonus":2,"name":"Rare Revisit","description":"+{bonus} score"},
          {"id":3,"type":"revisit","rarity":"epic","bonus":3,"name":"Epic Revisit","description":"+{bonus} score"}
        ]
        """#.utf8)

    private func makeModel(body: String) -> PowerUpInventoryViewModel {
        let tokenStore = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokenStore.save("session-token")
        let session = FakeURLSession { request in
            #expect(request.url?.path == "/api/me")
            return (Data(body.utf8),
                    HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        return PowerUpInventoryViewModel(
            service: AuthenticatedService(tokenStore: tokenStore, urlSession: session),
            catalog: PowerUpCatalog(data: catalogData)
        )
    }

    @Test func sortsByRarityThenNameAndResolvesDefinitions() async {
        let model = makeModel(body: #"{"powerups":{"3":1,"1":4,"2":2}}"#)
        await model.load()
        #expect(model.items.map(\.id) == [1, 2, 3])
        #expect(model.items.map(\.count) == [4, 2, 1])
        #expect(model.items.first?.name == "Common Revisit")
        #expect(model.items.last?.detail == "+3 score")
    }

    @Test func unknownIdsSortLastWithFallbackName() async {
        let model = makeModel(body: #"{"powerups":{"99":1,"1":1}}"#)
        await model.load()
        #expect(model.items.map(\.id) == [1, 99])
        #expect(model.items.last?.name == "Unknown power-up #99")
        #expect(model.items.last?.rarity == nil)
    }

    @Test func emptyInventoryAndFailuresYieldNoItems() async {
        let model = makeModel(body: #"{"visited":5}"#)
        await model.load()
        #expect(model.items.isEmpty)
        let failing = PowerUpInventoryViewModel(
            service: AuthenticatedService(
                tokenStore: AuthTokenStore(keyValueStore: InMemoryKeyValueStore()),
                urlSession: FakeURLSession { _ in throw URLError(.notConnectedToInternet) }
            ),
            catalog: PowerUpCatalog(data: catalogData)
        )
        await failing.load()
        #expect(failing.items.isEmpty)
    }
}
