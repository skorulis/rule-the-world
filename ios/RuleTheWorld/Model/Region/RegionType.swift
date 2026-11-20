import Foundation

nonisolated enum RegionType: Int, Codable, Sendable, CaseIterable {
    case none = 0
    case country = 1
    case state = 2

    var name: String {
        switch self {
        case .none: "none"
        case .country: "country"
        case .state: "state"
        }
    }

    init?(name: String) {
        guard let match = Self.allCases.first(where: { $0.name == name }) else { return nil }
        self = match
    }
}
