import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ConsumePowerUpRequestTests {
    private func service(status: Int = 200, body: String, onRequest: @escaping (URLRequest) -> Void = { _ in }) -> AuthenticatedService {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        tokens.save("session-token")
        return AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            onRequest(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func postsPowerUpIdAndLocation() async throws {
        var captured: URLRequest?
        _ = try await service(body: #"{"powerups":{},"visits":[]}"#, onRequest: { captured = $0 })
            .consumePowerUp(id: 2, latitude: -33.89, longitude: 151.19)
        let request = try #require(captured)
        #expect(request.url?.path == "/api/powerup/consume")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        let payload = try #require(request.httpBody)
        let body = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
        #expect(body?["powerup"] as? Int == 2)
        let location = body?["location"] as? [String: Any]
        #expect(location?["latitude"] as? Double == -33.89)
        #expect(location?["longitude"] as? Double == 151.19)
    }

    @Test func decodesInventoryAndChangedHexes() async throws {
        let response = try await service(body: """
            {"powerups":{"1":2},"visits":[{"totals":{"totalVisits":4,"rivalScore":1.5},"userVisit":{"cell":"8a2830828767fff","lastVisit":"2026-11-20T10:00:00Z","score":6,"lastScore":0.5,"total":2}}]}
            """).consumePowerUp(id: 1, latitude: 0, longitude: 0)
        #expect(response.powerups == ["1": 2])
        let info = try #require(response.visits.first)
        #expect(info.cell == HexCell(rawValue: 0x8a2830828767fff))
        #expect(info.totals == HexTotals(totalVisits: 4, rivalScore: 1.5))
        #expect(info.userVisit?.score == 6)
    }

    @Test func rejectsFailedResponses() async {
        await #expect(throws: (any Error).self) {
            _ = try await service(status: 500, body: "{}").consumePowerUp(id: 1, latitude: 0, longitude: 0)
        }
    }
}
