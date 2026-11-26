import SwiftUI

enum HexState: String, Codable, CaseIterable, Comparable {
    case unclaimed
    case rivalOwned
    case partialVisit
    case explored
    case visited
    case owned
    case contested

    nonisolated static func forScore(_ score: Double, rivalScore: Double?, hasVisited: Bool = true) -> HexState {
        if let rivalScore, rivalScore > score { return .rivalOwned }
        guard hasVisited else {
            guard let rivalScore else { return .explored }
            return score > rivalScore ? .owned : .explored
        }
        guard score >= HexVisit.maxDailyScore else { return .partialVisit }
        guard let rivalScore else { return .visited }
        return score > rivalScore ? .owned : .contested
    }

    /// Whether the user currently owns the hex in this state.
    nonisolated var isOwned: Bool {
        self == .visited || self == .owned
    }

    nonisolated var color: Color? {
        switch self {
        case .unclaimed:
            return nil
        case .rivalOwned:
            return .red
        case .partialVisit:
            return .cyan
        case .explored:
            return .mint
        case .visited, .owned:
            return .blue
        case .contested:
            return .purple
        }
    }

    nonisolated static func < (lhs: HexState, rhs: HexState) -> Bool {
        let order = Self.allCases
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}
