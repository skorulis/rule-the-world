import SwiftUI

enum HexState: String, Codable, CaseIterable, Comparable {
    case unclaimed
    case partialVisit
    case visited
    case owned
    case contested

    nonisolated static func forScore(_ score: Double, rivalScore: Double) -> HexState {
        if score > rivalScore { return .owned }
        if rivalScore > score { return .visited }
        return .contested
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
            return Color(red: 0.8, green: 0.6, blue: 0)
        case .contested:
            return .red
        }
    }

    nonisolated static func < (lhs: HexState, rhs: HexState) -> Bool {
        let order = Self.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
