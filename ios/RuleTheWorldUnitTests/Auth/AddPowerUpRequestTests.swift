import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct AddPowerUpRequestTests {
    private func service(status: Int = 200, body: String) -> AuthenticatedService {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("session-token")
        return AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            #expect(request.url?.path == "/api/debug/add_powerup")
            #expect(request.httpMethod == "POST")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func decodesGrantedPowerUpAndInventory() async throws {
        let response = try await service(body: """
            {"powerup":{"id":2,"type":"attack","rarity":"rare","bonus":2,"squares":5,"description":"+{bonus} score"},"powerups":{"2":1,"1":3}}
            """).addPowerUp()
        #expect(response.powerup.id == 2)
        #expect(response.powerup.displayName == "Rare Attack")
        #expect(response.powerups == ["1": 3, "2": 1])
    }

    @Test func rejectsFailedResponses() async {
        await #expect(throws: (any Error).self) {
            _ = try await service(status: 500, body: "{}").addPowerUp()
        }
    }
}
