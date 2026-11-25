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
}
