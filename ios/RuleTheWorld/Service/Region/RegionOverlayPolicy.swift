import Foundation

nonisolated enum RegionOverlayPolicy {
    enum Level: String, CaseIterable, Sendable {
        case medium
        case coarse
        case state
        case suburb
    }

    static let minimumWidthMeters = 750_000.0
    static let suburbWidthMeters = 60_000.0
    static let coarseWidthMeters = 6_000_000.0
    static let hysteresis = 0.08

    static func level(visibleWidthMeters width: Double, previous: Level?) -> Level? {
        guard width.isFinite, width > 0 else { return nil }
        let suburb = suburbWidthMeters
            * (previous == .suburb ? 1 + hysteresis : previous == .state ? 1 - hysteresis : 1)
        guard width >= suburb else { return .suburb }
        let minimum = minimumWidthMeters
            * (previous == .state || previous == .suburb ? 1 + hysteresis : previous == nil ? 1 : 1 - hysteresis)
        guard width >= minimum else { return .state }
        let coarse = coarseWidthMeters * (previous == .coarse ? 1 - hysteresis : 1)
        return width >= coarse ? .coarse : .medium
    }
}
