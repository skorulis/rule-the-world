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
    private let otherCell = HexCell(rawValue: 0x8A283082876FFFF)

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

    @Test func fetchesTotalsForTheRequestedCells() async throws {
        let box = TotalsRequestBox()
        let service = AuthenticatedService(tokenStore: tokenStore(), urlSession: FakeURLSession { request in
            box.request = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let body = """
                {"visits":[
                    {"cell":"8a2830828007fff","totals":{"totalVisits":105,"rivalScore":30.25},"userVisit":{
                        "cell":"8a2830828007fff","lastVisit":"2026-11-20T10:00:00.000Z",
                        "total":42,"score":12.5,"lastScore":0.5}},
                    {"cell":"8a283082876ffff","totals":null,"userVisit":null}
                ]}
                """
            return (Data(body.utf8), response)
        })
        let totals = try await service.totals(for: [cell, otherCell])
        let request = try #require(box.request)
        #expect(request.url?.path == "/api/hex-visits/info")
        #expect(request.httpMethod == "GET")
        #expect(request.url?.query() == "cells=8a2830828007fff,8a283082876ffff")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        #expect(totals.count == 2)
        #expect(totals[0].totals?.totalVisits == 105)
        #expect(totals[0].totals?.rivalScore == 30.25)
        #expect(totals[0].cell == cell)
        #expect(totals[0].userVisit == HexVisit(
            lastVisit: Date(timeIntervalSince1970: 1_795_168_800),
            score: 12.5, lastScore: 0.5, total: 42
        ))
        #expect(totals[1] == HexInfo(cell: otherCell, totals: nil, userVisit: nil))
    }

    @Test func decodesMissingUserVisit() async throws {
        let body = """
            {"visits":[{"cell":"8a2830828007fff","totals":{"totalVisits":7,"rivalScore":9},"userVisit":null}]}
            """
        let totals = try await service(body: body).totals(for: [cell])
        #expect(totals == [HexInfo(cell: cell, totals: HexTotals(totalVisits: 7, rivalScore: 9), userVisit: nil)])
    }

    @Test func rejectsFailedRequestsAndMalformedPayloads() async {
        for service in [
            service(status: 401, body: "{}"),
            service(status: 500, body: "{\"visits\":[]}"),
            service(body: "not json"),
            service(body: """
                {"visits":[{"cell":"8a2830828007fff","totals":{"totalVisits":-1,"rivalScore":0},"userVisit":null}]}
                """),
            service(body: """
                {"visits":[{"cell":"8a2830828007fff","totals":{"totalVisits":1,"rivalScore":-2},"userVisit":null}]}
                """),
            service(body: """
                {"visits":[{"cell":"8a2830828007fff","totals":{"totalVisits":1,"rivalScore":0},"userVisit":{
                    "cell":"not-a-cell","lastVisit":"2026-11-20T10:00:00.000Z",
                    "total":1,"score":1,"lastScore":0.5}}]}
                """),
        ] {
            await #expect(throws: (any Error).self) {
                _ = try await service.totals(for: [cell])
            }
        }
    }
}
