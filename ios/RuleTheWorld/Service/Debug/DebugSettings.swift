import ASKCore
import Foundation

enum NetworkEndpoint: String, CaseIterable, Identifiable {
    case local
    case mock

    var id: String { rawValue }

    var title: String {
        switch self {
        case .local: "Local server (localhost:3001)"
        case .mock: "Mocked responses"
        }
    }

    func makeSession() -> URLSessionProtocol {
        switch self {
        case .local:
            return URLSession(configuration: .default)
        case .mock:
            return MockURLSession()
        }
    }
}

struct DebugSettings {
    static let endpointKey = "debug.networkEndpoint"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var endpoint: NetworkEndpoint {
        get {
            defaults.string(forKey: Self.endpointKey)
                .flatMap { NetworkEndpoint(rawValue: $0) } ?? .local
        }
        nonmutating set {
            defaults.set(newValue.rawValue, forKey: Self.endpointKey)
        }
    }
}
