import SwiftUI

enum HexState: String, Codable, CaseIterable {
    case unclaimed
    case mine
    case rival
    case neutral

    nonisolated var color: Color? {
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
