import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

private final class VisitRequestBox: @unchecked Sendable {
    var request: URLRequest?
}

@MainActor
struct HexVisitUploadServiceTests {
    private func entry() -> HexVisitLog {
        HexVisitLog(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cell: HexCell(rawValue: 0x8A283082876FFFF),
            latitude: -33.89, longitude: 151.19, speed: 2, score: 0.5,
            uploadID: "visit-1"
        )
    }

    private func service(status: Int = 200, body: String) -> HexVisitUploadService {
        HexVisitUploadService(urlSession: FakeURLSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
            return (Data(body.utf8), response)
        })
    }

    @Test func postsAuthenticatedBatchWithExplicitWireFormat() async throws {
        let box = VisitRequestBox()
        let uploader = HexVisitUploadService(urlSession: FakeURLSession { request in
            box.request = request
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (Data("{\"acceptedIds\":[\"visit-1\"],\"visits\":[]}".utf8), response)
        })
        let accepted = try await uploader.upload([entry()], token: "session-token")
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
        #expect(visits[0]["latitude"] == nil)
        #expect(accepted == ["visit-1"])
    }

    @Test func rejectsFailedRequestsAndMalformedAcknowledgements() async {
        for uploader in [
            service(status: 401, body: "{}"),
            service(status: 500, body: "{\"acceptedIds\":[\"visit-1\"]}"),
            service(body: "{}"),
            service(body: "{\"acceptedIds\":[\"unknown\"]}"),
            service(body: "{\"acceptedIds\":[\"visit-1\",\"visit-1\"]}"),
        ] {
            await #expect(throws: (any Error).self) {
                _ = try await uploader.upload([entry()], token: "token")
            }
        }
    }

    @Test func allowsPartialAcknowledgementsWithoutAcknowledgingOtherRows() async throws {
        let accepted = try await service(body: "{\"acceptedIds\":[]}").upload([entry()], token: "token")
        #expect(accepted.isEmpty)
    }
}
