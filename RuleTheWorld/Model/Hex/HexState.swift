import SwiftUI

enum HexState: String, Codable, CaseIterable {
    case unclaimed
    case mine
    case rival
    case neutral

    var next: HexState {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }

    var color: Color? {
        switch self {
        case .unclaimed:
            return nil
        case .mine:
            return .blue
        case .rival:
            return .red
        case .neutral:
            return .green
        }
    }
}
