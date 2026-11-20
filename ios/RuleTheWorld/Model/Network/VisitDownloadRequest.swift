import ASKCore
import Foundation

struct VisitDownloadRequest: HTTPRequest {
    typealias ResponseType = [HexVisit]

    let endpoint = "api/hex-visits"
    let method = "GET"
    let params: [String: String] = [:]
    let body: Data? = nil
    let headers: [String: String] = [:]

    func decode(data: Data, response: URLResponse) throws -> [HexVisit] {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(VisitDownloadResponse.self, from: data).visits
    }
}
