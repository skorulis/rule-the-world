import Foundation
import Testing
@testable import RuleTheWorld

private final class StubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    // swiftlint:disable:next static_over_final_class
    override class func canInit(with request: URLRequest) -> Bool { true }
    // swiftlint:disable:next static_over_final_class
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeService(
    handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)
) -> AuthService {
    StubURLProtocol.handler = handler
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [StubURLProtocol.self]
    return AuthService(
        baseURL: URL(string: "http://localhost:3000")!,
        session: URLSession(configuration: configuration)
    )
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

private func response(
    url: URL,
    status: Int,
    headers: [String: String] = [:],
    body: String = "{}"
) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(
        url: url,
        statusCode: status,
        httpVersion: nil,
        headerFields: headers
    )!
    return (response, Data(body.utf8))
}

@Suite
struct AuthServiceTests {
    @Test func signInPostsCredentialsAndReturnsHeaderToken() async throws {
        var capturedRequest: URLRequest?
        let service = makeService { request in
            capturedRequest = request
            return response(
                url: request.url!,
                status: 200,
                headers: ["set-auth-token": "header-token"],
                body: "{\"token\":\"body-token\",\"user\":{}}"
            )
        }

        let token = try await service.signIn(email: "a@b.c", password: "pw")

        #expect(token == "header-token")
        #expect(capturedRequest?.url?.path == "/api/auth/sign-in/email")
        #expect(capturedRequest?.httpMethod == "POST")
        #expect(capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/json")
        let json = try jsonBody(try #require(capturedRequest))
        #expect(json["email"] == "a@b.c")
        #expect(json["password"] == "pw")
    }

    @Test func signUpPostsNameAndReturnsBodyTokenWhenHeaderMissing() async throws {
        var capturedRequest: URLRequest?
        let service = makeService { request in
            capturedRequest = request
            return response(
                url: request.url!,
                status: 200,
                body: "{\"token\":\"body-token\"}"
            )
        }

        let token = try await service.signUp(name: "Alex", email: "a@b.c", password: "pw")

        #expect(token == "body-token")
        #expect(capturedRequest?.url?.path == "/api/auth/sign-up/email")
        let json = try jsonBody(try #require(capturedRequest))
        #expect(json["name"] == "Alex")
    }

    @Test func invalidCredentialsThrows() async {
        let service = makeService { request in
            response(url: request.url!, status: 401)
        }

        await #expect(throws: AuthError.self) {
            _ = try await service.signIn(email: "a@b.c", password: "bad")
        }
    }

    @Test func missingTokenThrows() async {
        let service = makeService { request in
            response(url: request.url!, status: 200, body: "{\"user\":{}}")
        }

        await #expect(throws: AuthError.self) {
            _ = try await service.signIn(email: "a@b.c", password: "pw")
        }
    }
}
