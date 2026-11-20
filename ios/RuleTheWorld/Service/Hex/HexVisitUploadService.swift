import ASKCore
import Foundation

@MainActor
protocol HexVisitUploading {
    func upload(_ entries: [HexVisitLog]) async throws -> Set<String>
}

extension AuthenticatedService: HexVisitUploading {
    func upload(_ entries: [HexVisitLog]) async throws -> Set<String> {
        let response = try await execute(request: VisitBatchRequest(entries: entries))
        let accepted = Set(response.acceptedIds)
        guard accepted.isSubset(of: Set(entries.map(\.uploadID))), accepted.count == response.acceptedIds.count else {
            throw URLError(.cannotParseResponse)
        }
        return accepted
    }
}

nonisolated private struct VisitBatchResponse: Decodable {
    let acceptedIds: [String]
}

nonisolated private struct VisitBatchBody: Encodable {
    struct Visit: Encodable {
        let id: String
        let cell: String
        let timestamp: String
        let score: Double
        let count: Int
    }

    let visits: [Visit]

    init(entries: [HexVisitLog]) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        visits = entries.map {
            Visit(
                id: $0.uploadID, cell: $0.cell.description,
                timestamp: formatter.string(from: $0.timestamp), score: $0.score, count: $0.count
            )
        }
    }
}

private struct VisitBatchRequest: HTTPRequest {
    typealias ResponseType = VisitBatchResponse

    let endpoint = "api/hex-visits/batch"
    let method = "POST"
    let params: [String: String] = [:]
    let headers = ["Content-Type": "application/json"]
    let body: Data?

    init(entries: [HexVisitLog]) throws {
        body = try JSONEncoder().encode(VisitBatchBody(entries: entries))
    }

    func decode(data: Data, response: URLResponse) throws -> VisitBatchResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(VisitBatchResponse.self, from: data)
    }
}
