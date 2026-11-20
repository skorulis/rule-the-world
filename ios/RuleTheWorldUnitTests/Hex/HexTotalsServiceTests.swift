import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

private final class TotalsRequestBox: @unchecked Sendable {
    var request: URLRequest?
}

@MainActor
struct HexTotalsServiceTests {
    private let cell = HexCell(rawValue: 0x8A2830828007FFF)

    private func tokenStore() -> AuthTokenStore {
        let store = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
        store.save("session-token")
        return store
    }

    private func service(status: Int = 200, body: String) -> AuthenticatedService {
        AuthenticatedService(tokenStore: tokenStore(), urlSession: FakeURLSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func fetchesTotalsForTheRequestedCell() async throws {
        let box = TotalsRequestBox()
        let service = AuthenticatedService(tokenStore: tokenStore(), urlSession: FakeURLSession { request in
            box.request = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
                {"totalVisits":105,"rivalScore":30.25,"userVisit":{
                    "cell":"8a2830828007fff","lastVisit":"2026-11-20T10:00:00.000Z",
                    "total":42,"score":12.5,"lastScore":0.5}}
                """
            return (Data(body.utf8), response)
        })
        let totals = try await service.totals(for: cell)
        let request = try #require(box.request)
        #expect(request.url?.path == "/api/hex-visits/8a2830828007fff")
        #expect(request.httpMethod == "GET")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        #expect(totals.totalVisits == 105)
        #expect(totals.rivalScore == 30.25)
        #expect(totals.userVisit == HexVisit(
            cell: cell, lastVisit: Date(timeIntervalSince1970: 1_795_168_800),
            score: 12.5, lastScore: 0.5, total: 42
        ))
    }

    @Test func decodesMissingUserVisit() async throws {
        let body = "{\"totalVisits\":7,\"rivalScore\":9,\"userVisit\":null}"
        let totals = try await service(body: body).totals(for: cell)
        #expect(totals == HexInfo(totalVisits: 7, rivalScore: 9, userVisit: nil))
    }

    @Test func rejectsFailedRequestsAndMalformedPayloads() async {
        for service in [
            service(status: 401, body: "{}"),
            service(status: 500, body: "{\"totalVisits\":1,\"rivalScore\":1,\"userVisit\":null}"),
            service(body: "{}"),
            service(body: "{\"totalVisits\":-1,\"rivalScore\":0,\"userVisit\":null}"),
            service(body: "{\"totalVisits\":1,\"rivalScore\":-2,\"userVisit\":null}"),
            service(body: """
                {"totalVisits":1,"rivalScore":0,"userVisit":{
                    "cell":"not-a-cell","lastVisit":"2026-11-20T10:00:00.000Z",
                    "total":1,"score":1,"lastScore":0.5}}
                """)
        ] {
            await #expect(throws: (any Error).self) {
                _ = try await service.totals(for: cell)
            }
        }
    }
}
