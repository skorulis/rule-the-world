import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct DailyRewardRequestTests {
    private func service(status: Int = 200, body: String) -> AuthenticatedService {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("session-token")
        return AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            #expect(request.url?.path == "/api/powerup/daily")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func decodesGrantedPowerUpAndInventory() async throws {
        let response = try await service(body: """
            {"powerup":{"id":4,"type":"exploration","rarity":"common","bonus":1,"description":"+{bonus} score"},
            "powerups":{"4":1,"1":3}}
            """).claimDailyReward()
        #expect(response.powerup.id == 4)
        #expect(response.powerup.displayName == "Common Exploration")
        #expect(response.powerups == ["1": 3, "4": 1])
    }

    @Test func rejectsAlreadyClaimedAndFailedResponses() async {
        for (status, body) in [(409, #"{"error":"Daily reward already claimed"}"#), (500, "{}"), (200, "not json")] {
            await #expect(throws: (any Error).self) {
                _ = try await service(status: status, body: body).claimDailyReward()
            }
        }
    }
}
