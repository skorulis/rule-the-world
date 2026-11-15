import Foundation

struct HexCell: Hashable, Codable, Identifiable, CustomStringConvertible {
    let rawValue: UInt64

    var id: UInt64 { rawValue }

    var description: String {
        String(rawValue, radix: 16)
    }
}
