import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

private final class VisitRequestBox: @unchecked Sendable {
    var request: URLRequest?
}

@MainActor
struct HexVisitUploadServiceTests {
    private func tokenStore() -> AuthTokenStore {
        let store = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        store.save("session-token")
        return store
    }

    @Test func authorizationUsesCurrentTokenAndReplacesExistingHeader() throws {
        let tokens = tokenStore()
        let service = AuthenticatedService(tokenStore: tokens)
        var request = URLRequest(url: URL(string: "http://localhost:3001/api/profile")!)
        request.setValue("Bearer stale-token", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        try service.modify(request: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        tokens.save("updated-token")
        try service.modify(request: &request)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer updated-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test func signedOutRequestsFailBeforeReachingTheNetwork() async {
        let tokens = tokenStore()
        let box = VisitRequestBox()
        let service = AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            box.request = request
            throw URLError(.badServerResponse)
        })
        tokens.clear()
        await #expect(throws: URLError(.userAuthenticationRequired)) {
            _ = try await service.upload([entry()])
        }
        #expect(box.request == nil)
    }

    private func entry() -> HexVisitLog {
        HexVisitLog(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cell: HexCell(rawValue: 0x8A283082876FFFF),
            latitude: -33.89, longitude: 151.19, speed: 2, score: 0.5,
            uploadID: "visit-1"
        )
    }

    private func service(status: Int = 200, body: String) -> AuthenticatedService {
        AuthenticatedService(tokenStore: tokenStore(), urlSession: FakeURLSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func postsAuthenticatedBatchWithExplicitWireFormat() async throws {
        let box = VisitRequestBox()
        let uploader = AuthenticatedService(tokenStore: tokenStore(), urlSession: FakeURLSession { request in
            box.request = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{\"acceptedIds\":[\"visit-1\"],\"visits\":[],\"hexInfos\":[]}".utf8), response)
        })
        let accepted = try await uploader.upload([entry()])
        let request = try #require(box.request)
        #expect(request.url?.path == "/api/hex-visits/batch")
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let data = try #require(request.httpBody)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let visits = try #require(json["visits"] as? [[String: Any]])
        #expect(visits.count == 1)
        #expect(visits[0]["id"] as? String == "visit-1")
        #expect(visits[0]["cell"] as? String == "8a283082876ffff")
        #expect(visits[0]["timestamp"] as? String == "2023-11-14T22:13:20.000Z")
        #expect(visits[0]["score"] as? Double == 0.5)
        #expect(visits[0]["count"] as? Int == 1)
        #expect(visits[0]["latitude"] == nil)
        #expect(accepted.acceptedIds == ["visit-1"])
        #expect(accepted.hexInfos.isEmpty)
    }

    @Test func rejectsFailedRequestsAndMalformedAcknowledgements() async {
        for uploader in [
            service(status: 401, body: "{}"),
            service(status: 500, body: "{\"acceptedIds\":[\"visit-1\"]}"),
            service(body: "{}"),
            service(body: "{\"acceptedIds\":[\"unknown\"],\"hexInfos\":[]}"),
            service(body: "{\"acceptedIds\":[\"visit-1\",\"visit-1\"],\"hexInfos\":[]}"),
            service(body: "{\"acceptedIds\":[\"visit-1\"]}"),
        ] {
            await #expect(throws: (any Error).self) {
                _ = try await uploader.upload([entry()])
            }
        }
    }

    @Test func allowsPartialAcknowledgementsWithoutAcknowledgingOtherRows() async throws {
        let accepted = try await service(body: "{\"acceptedIds\":[],\"hexInfos\":[]}").upload([entry()])
        #expect(accepted.acceptedIds.isEmpty)
    }
}
