import SwiftUI

enum HexState: String, Codable, CaseIterable, Comparable {
    case unclaimed
    case partialVisit
    case explored
    case visited
    case owned
    case contested

    nonisolated static func forScore(_ score: Double, rivalScore: Double?, hasVisited: Bool = true) -> HexState {
        guard hasVisited else {
            guard let rivalScore else { return .explored }
            return score > rivalScore ? .owned : .explored
        }
        guard score >= HexVisit.maxDailyScore else { return .partialVisit }
        guard let rivalScore else { return .visited }
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
        case .explored:
            return .purple
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
