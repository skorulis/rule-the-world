import Foundation

struct HexVisit: Hashable, Codable, Sendable {
    var cell: HexCell
    var lastVisit: Date
    var score: Double
    var lastScore: Double
}
