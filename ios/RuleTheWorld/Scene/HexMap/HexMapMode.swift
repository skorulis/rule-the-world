import Foundation

enum HexMapMode: String, CaseIterable, Identifiable {
    case territory
    case exploration

    var id: Self { self }

    var title: String {
        switch self {
        case .territory:
            return "Territory"
        case .exploration:
            return "Exploration"
        }
    }

    var imageName: String {
        switch self {
        case .territory:
            return "HexOwned"
        case .exploration:
            return "HexVisited"
        }
    }
}
