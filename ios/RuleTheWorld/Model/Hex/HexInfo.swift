import Foundation

nonisolated struct HexInfo: Codable, Hashable, Sendable {
    nonisolated static let cellUserInfoKey = CodingUserInfoKey(rawValue: "hexCell")!

    var cell: HexCell
    var totals: HexTotals?
    var userVisit: HexVisit?
    var lastUpdate: Date?

    init(cell: HexCell, totals: HexTotals?, userVisit: HexVisit?, lastUpdate: Date? = nil) {
        self.cell = cell
        self.totals = totals
        self.userVisit = userVisit
        self.lastUpdate = lastUpdate
    }

    private enum CodingKeys: String, CodingKey {
        case cell, totals, userVisit, lastUpdate
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totals = try container.decodeIfPresent(HexTotals.self, forKey: .totals)
        userVisit = try container.decodeIfPresent(HexVisit.self, forKey: .userVisit)
        lastUpdate = try container.decodeIfPresent(Date.self, forKey: .lastUpdate)
        if let rawValue = try container.decodeIfPresent(String.self, forKey: .cell) {
            cell = try Self.parseCell(rawValue, forKey: .cell, in: container)
        } else if let nested = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: .userVisit),
                  let rawValue = try nested.decodeIfPresent(String.self, forKey: .cell) {
            guard let value = UInt64(rawValue, radix: 16) else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath, debugDescription: "Invalid hex cell ID"
                ))
            }
            cell = HexCell(rawValue: value)
        } else if let fallback = decoder.userInfo[Self.cellUserInfoKey] as? HexCell {
            cell = fallback
        } else {
            throw DecodingError.keyNotFound(
                CodingKeys.cell,
                .init(codingPath: decoder.codingPath, debugDescription: "Missing hex cell ID")
            )
        }
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(cell.description, forKey: .cell)
        try container.encodeIfPresent(totals, forKey: .totals)
        try container.encodeIfPresent(userVisit, forKey: .userVisit)
        try container.encodeIfPresent(lastUpdate, forKey: .lastUpdate)
    }

    private nonisolated static func parseCell(
        _ rawValue: String,
        forKey key: CodingKeys,
        in container: KeyedDecodingContainer<CodingKeys>
    ) throws -> HexCell {
        guard let value = UInt64(rawValue, radix: 16) else {
            throw DecodingError.dataCorruptedError(
                forKey: key, in: container, debugDescription: "Invalid hex cell ID"
            )
        }
        return HexCell(rawValue: value)
    }
}
