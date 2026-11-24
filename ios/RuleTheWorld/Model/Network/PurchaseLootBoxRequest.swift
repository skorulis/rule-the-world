import ASKCore
import Foundation

nonisolated private struct PurchaseLootBoxBody: Encodable {
    let box: Int
    let count: Int
}

struct PurchaseLootBoxRequest: HTTPRequest {
    typealias ResponseType = LootBoxPurchaseResponse

    let endpoint = "api/shop"
    let method = "POST"
    let params: [String: String] = [:]
    let headers = ["Content-Type": "application/json"]
    let body: Data?

    init(box id: Int, count: Int) throws {
        body = try JSONEncoder().encode(PurchaseLootBoxBody(box: id, count: count))
    }

    func decode(data: Data, response: URLResponse) throws -> LootBoxPurchaseResponse {
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            if let error = try? JSONDecoder().decode(LootBoxPurchaseFailure.self, from: data) {
                throw error
            }
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(LootBoxPurchaseResponse.self, from: data)
    }
}

nonisolated struct LootBoxPurchaseFailure: Decodable, LocalizedError, Sendable {
    let error: String

    var errorDescription: String? { error }
}

nonisolated struct LootBoxPurchaseResponse: Decodable, Sendable {
    let rewards: [PowerUpDefinition]
    let powerups: [String: Int]
    let coins: Int
}
