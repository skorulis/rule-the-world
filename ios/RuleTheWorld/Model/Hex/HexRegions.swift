import Foundation

nonisolated struct HexRegions: Codable, Hashable, Sendable {
    var country: Int64?
    var state: Int64?
    var suburb: Int64?

    init(country: Int64? = nil, state: Int64? = nil, suburb: Int64? = nil) {
        self.country = country
        self.state = state
        self.suburb = suburb
    }

    private enum CodingKeys: String, CodingKey {
        case country, state, suburb
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        country = try Self.decodeId(from: container, forKey: .country)
        state = try Self.decodeId(from: container, forKey: .state)
        suburb = try Self.decodeId(from: container, forKey: .suburb)
    }

    private nonisolated static func decodeId(
        from container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys
    ) throws -> Int64? {
        if let value = try container.decodeIfPresent(Int64.self, forKey: key) {
            return value > 0 ? value : nil
        }
        if let string = try container.decodeIfPresent(String.self, forKey: key),
           let value = Int64(string) {
            return value > 0 ? value : nil
        }
        return nil
    }
}
