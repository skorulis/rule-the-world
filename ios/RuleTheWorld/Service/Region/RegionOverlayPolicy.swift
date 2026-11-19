import Foundation

nonisolated enum RegionOverlayPolicy {
    enum Level: String, CaseIterable, Sendable {
        case medium
        case coarse
    }

    static let minimumWidthMeters = 750_000.0
    static let coarseWidthMeters = 6_000_000.0
    static let hysteresis = 0.08

    static func level(visibleWidthMeters width: Double, previous: Level?) -> Level? {
        guard width.isFinite, width > 0 else { return nil }
        let minimum = minimumWidthMeters * (previous == nil ? 1 : 1 - hysteresis)
        guard width >= minimum else { return nil }
        let coarse = coarseWidthMeters * (previous == .coarse ? 1 - hysteresis : 1)
        return width >= coarse ? .coarse : .medium
    }
}
