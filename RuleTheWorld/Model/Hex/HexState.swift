import SwiftUI

enum HexState: String, Codable, CaseIterable, Comparable {
    case unclaimed
    case partialVisit
    case visited
    case owned
    case contested

    nonisolated static func forScore(_ score: Double) -> HexState {
        score >= HexVisit.maxDailyScore ? .visited : .partialVisit
    }

    nonisolated var color: Color? {
        switch self {
        case .unclaimed:
            return nil
        case .partialVisit:
            return .cyan
        case .visited:
            return .blue
        case .owned:
            return .indigo
        case .contested:
            return .orange
        }
    }

    nonisolated static func < (lhs: HexState, rhs: HexState) -> Bool {
        let order = Self.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
