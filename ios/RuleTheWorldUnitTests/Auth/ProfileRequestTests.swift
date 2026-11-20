import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct ProfileRequestTests {
    private func service(status: Int = 200, body: String, token: String? = "session-token") -> AuthenticatedService {
        let tokens = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        if let token { tokens.save(token) }
        return AuthenticatedService(tokenStore: tokens, urlSession: FakeURLSession { request in
            #expect(request.url?.path == "/api/me")
            #expect(request.httpMethod == "GET")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func fetchesAuthenticatedProfileAndNumericIDs() async throws {
        let summary = try await service(body: """
            {"user":{"id":"u1"},"visited":10,"owned":5,
            "regions":[{"id":1159320355,"visited":10,"owned":5}]}
            """).fetchProfile()
        #expect(summary.visited == 10)
        #expect(summary.owned == 5)
        #expect(summary.regions.first?.id == 1159320355)
        #expect(summary.regions.first?.visited == 10)
        #expect(summary.regions.first?.owned == 5)
    }

    @Test func skipsMalformedRegionsWithoutDiscardingValidRows() async throws {
        let summary = try await service(body: """
            {"visited":10,"owned":5,"regions":[
            null, "bad", 42, {},
            {"id":1,"visited":2},
            {"id":0,"visited":1,"owned":0},
            {"id":-1,"visited":1,"owned":0},
            {"id":2,"visited":-1,"owned":0},
            {"id":3,"visited":1,"owned":-1},
            {"id":4,"visited":1,"owned":2},
            {"id":"5","visited":1,"owned":0},
            {"id":6,"visited":2,"owned":1},
            {"id":7,"visited":0,"owned":0}]}
            """).fetchProfile()
        #expect(summary.regions.map(\.id) == [6, 7])
        #expect(summary.visited == 10)
        #expect(summary.owned == 5)
    }

    @Test func missingOrInvalidFieldsAreAbsentAndRealZeroesSurvive() async throws {
        for body in [
            "{}", #"{"visited":null,"owned":null,"regions":null}"#,
            #"{"visited":-1,"owned":"bad","regions":{}}"#,
        ] {
            let summary = try await service(body: body).fetchProfile()
            #expect(summary.visited == nil)
            #expect(summary.owned == nil)
            #expect(summary.regions.isEmpty)
        }
        let zero = try await service(body: #"{"visited":0,"owned":0,"regions":[]}"#).fetchProfile()
        #expect(zero.visited == 0)
        #expect(zero.owned == 0)
        let partial = try await service(body: #"{"owned":3}"#).fetchProfile()
        #expect(partial.visited == nil)
        #expect(partial.owned == 3)
        let invalidOwned = try await service(body: #"{"visited":2,"owned":3}"#).fetchProfile()
        #expect(invalidOwned.visited == 2)
        #expect(invalidOwned.owned == nil)
    }

    @Test func rejectsFailedOrMalformedResponses() async {
        for (status, body) in [(401, "{}"), (500, "{}"), (200, "not json"), (200, "[]")] {
            await #expect(throws: (any Error).self) {
                _ = try await service(status: status, body: body).fetchProfile()
            }
        }
    }

    @Test func requiresStoredToken() async {
        await #expect(throws: URLError.self) {
            _ = try await service(body: "{}", token: nil).fetchProfile()
        }
    }
}
