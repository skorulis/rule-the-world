import ASKCore
import Foundation
import Testing
@testable import RuleTheWorld

private final class RequestBox: @unchecked Sendable {
    var request: URLRequest?
}

@MainActor
private func makeService(
    handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
) -> AuthService {
    AuthService(
        baseURL: "http://localhost:3001",
        urlSession: FakeURLSession(handler: handler)
    )
}

@MainActor
private func makeAuthenticatedService(
    token: String? = "session-token",
    handler: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse)
) -> AuthenticatedService {
    let store = AuthTokenStore(keyValueStore: InMemoryKeyValueStore())
    if let token { store.save(token) }
    return AuthenticatedService(tokenStore: store, urlSession: FakeURLSession(handler: handler))
}

private func jsonResponse(
    url: URL,
    status: Int,
    headers: [String: String] = [:],
    body: String = "{}"
) -> (Data, URLResponse) {
    let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
    return (Data(body.utf8), response)
}

private func bodyData(_ request: URLRequest) -> Data? {
    if let body = request.httpBody { return body }
    guard let stream = request.httpBodyStream else { return nil }
    stream.open()
    defer { stream.close() }
    var data = Data()
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
    defer { buffer.deallocate() }
    while stream.hasBytesAvailable {
        let read = stream.read(buffer, maxLength: 1024)
        if read <= 0 { break }
        data.append(buffer, count: read)
    }
    return data
}

private func jsonBody(_ request: URLRequest) throws -> [String: String] {
    let data = try #require(bodyData(request))
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
}

@Suite
struct AuthServiceTests {
    @Test func signInPostsCredentialsAndReturnsHeaderToken() async throws {
        let box = RequestBox()
        let service = await makeService { request in
            box.request = request
            return jsonResponse(
                url: request.url!,
                status: 200,
                headers: ["set-auth-token": "header-token"],
                body: "{\"token\":\"body-token\",\"user\":{}}"
            )
        }

        let token = try await service.signIn(email: "a@b.c", password: "pw")

        #expect(token == "header-token")
        #expect(box.request?.url?.path == "/api/auth/sign-in/email")
        #expect(box.request?.httpMethod == "POST")
        #expect(box.request?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(box.request?.value(forHTTPHeaderField: "Origin") == "http://localhost:3001")
        let json = try jsonBody(try #require(box.request))
        #expect(json["email"] == "a@b.c")
        #expect(json["password"] == "pw")
    }

    @Test func signUpPostsNameAndReturnsBodyTokenWhenHeaderMissing() async throws {
        let box = RequestBox()
        let service = await makeService { request in
            box.request = request
            return jsonResponse(
                url: request.url!,
                status: 200,
                body: "{\"token\":\"body-token\"}"
            )
        }

        let token = try await service.signUp(name: "Alex", email: "a@b.c", password: "pw")

        #expect(token == "body-token")
        #expect(box.request?.url?.path == "/api/auth/sign-up/email")
        let json = try jsonBody(try #require(box.request))
        #expect(json["name"] == "Alex")
    }

    @Test func fetchVisitsUsesBearerTokenAndDecodesWireFormat() async throws {
        let box = RequestBox()
        let service = await makeAuthenticatedService { request in
            box.request = request
            return jsonResponse(url: request.url!, status: 200, body: """
                {"visits":[{"totals":{"totalVisits":105,"rivalScore":30.25},"userVisit":{
                "cell":"8a283082876ffff","lastVisit":"2026-11-20T10:00:00.000Z",
                "score":12.5,"lastScore":0.5,"total":42}}]}
                """)
        }

        let visits = try await service.fetchVisits()

        #expect(box.request?.url?.path == "/api/hex-visits")
        #expect(box.request?.httpMethod == "GET")
        #expect(box.request?.value(forHTTPHeaderField: "Authorization") == "Bearer session-token")
        #expect(visits.count == 1)
        #expect(visits.first?.totals?.totalVisits == 105)
        #expect(visits.first?.totals?.rivalScore == 30.25)
        #expect(visits.first?.cell == HexCell(rawValue: 0x8A283082876FFFF))
        #expect(visits.first?.userVisit?.score == 12.5)
        #expect(visits.first?.userVisit?.total == 42)
        #expect(visits.first?.userVisit?.lastScore == 0.5)
        #expect(visits.first?.userVisit?.lastVisit == ISO8601DateFormatter().date(from: "2026-11-20T10:00:00Z"))
    }

    @Test func fetchVisitsRejectsFailedOrMalformedResponses() async {
        for (status, body) in [
            (401, "{\"visits\":[]}"),
            (500, "{\"visits\":[]}"),
            (200, "{}"),
            (200, """
                {"visits":[{"totals":{"totalVisits":1,"rivalScore":0},"userVisit":{
                "cell":"invalid","lastVisit":"2026-11-20T10:00:00Z",
                "score":1,"lastScore":1,"total":1}}]}
                """),
            (200, "{\"visits\":[{\"totals\":{\"totalVisits\":-1,\"rivalScore\":0},\"userVisit\":null}]}"),
            (200, "{\"visits\":[{\"totals\":{\"totalVisits\":1,\"rivalScore\":-2},\"userVisit\":null}]}"),
        ] {
            let service = await makeAuthenticatedService { request in
                jsonResponse(url: request.url!, status: status, body: body)
            }
            await #expect(throws: (any Error).self) {
                _ = try await service.fetchVisits()
            }
        }
    }

    @Test func fetchVisitsRequiresStoredToken() async {
        let box = RequestBox()
        let service = await makeAuthenticatedService(token: nil) { request in
            box.request = request
            return jsonResponse(url: request.url!, status: 200, body: "{\"visits\":[]}")
        }

        await #expect(throws: URLError.self) {
            _ = try await service.fetchVisits()
        }
        #expect(box.request == nil)
    }

    @Test func invalidCredentialsThrows() async {
        let service = await makeService { request in
            jsonResponse(url: request.url!, status: 401)
        }

        await #expect(throws: AuthError.self) {
            _ = try await service.signIn(email: "a@b.c", password: "bad")
        }
    }

    @Test func missingTokenThrows() async {
        let service = await makeService { request in
            jsonResponse(url: request.url!, status: 200, body: "{\"user\":{}}")
        }

        await #expect(throws: AuthError.self) {
            _ = try await service.signIn(email: "a@b.c", password: "pw")
        }
    }
}
