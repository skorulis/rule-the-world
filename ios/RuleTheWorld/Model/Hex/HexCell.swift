import Foundation

struct HexCell: nonisolated Hashable, Codable, Identifiable, CustomStringConvertible {
    let rawValue: UInt64

    nonisolated var id: UInt64 { rawValue }

    nonisolated var description: String {
        String(rawValue, radix: 16)
    }

    nonisolated static func == (lhs: HexCell, rhs: HexCell) -> Bool {
        lhs.rawValue == rhs.rawValue
    }

    nonisolated func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}
