import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct PurchaseLootBoxRequestTests {
    private func service(status: Int = 200, body: String, onRequest: @escaping (URLRequest) -> Void = { _ in }) -> AuthenticatedService {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("session-token")
        return AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            onRequest(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func postsBoxIdAndCount() async throws {
        var captured: URLRequest?
        _ = try await service(body: #"{"rewards":[],"powerups":{},"coins":90}"#, onRequest: { captured = $0 })
            .purchaseLootBox(id: 1, count: 5)
        let request = try #require(captured)
        #expect(request.url?.path == "/api/shop")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        let payload = try #require(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        #expect(body?["box"] as? Int == 1)
        #expect(body?["count"] as? Int == 5)
    }

    @Test func decodesRewardsInventoryAndCoins() async throws {
        let response = try await service(body: """
            {"rewards":[{"id":1,"type":"revisit","rarity":"common","bonus":1,"description":"+{bonus} score"}],"powerups":{"1":3},"coins":80}
            """).purchaseLootBox(id: 1, count: 1)
        #expect(response.rewards.count == 1)
        #expect(response.rewards.first?.displayName == "Common Revisit")
        #expect(response.powerups == ["1": 3])
        #expect(response.coins == 80)
    }

    @Test func surfacesServerErrorMessage() async {
        await #expect(throws: LootBoxPurchaseFailure.self) {
            _ = try await service(status: 409, body: #"{"error":"Not enough coins"}"#)
                .purchaseLootBox(id: 1, count: 1)
        }
    }

    @Test func rejectsFailedResponses() async {
        await #expect(throws: (any Error).self) {
            _ = try await service(status: 500, body: "{}").purchaseLootBox(id: 1, count: 1)
        }
    }
}
