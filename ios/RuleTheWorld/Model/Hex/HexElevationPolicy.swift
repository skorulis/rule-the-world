import Foundation

/// Quantizes the score margin on a hex into a discrete extrusion level for
/// the 3D map rendering. Higher levels mean a more decisive lead (in either
/// direction — color shows who is ahead).
enum HexElevationPolicy {
    static let maxLevel = 4

    /// Vertical lift per level as a fraction of the hexagon's edge length,
    /// so the extrusion looks the same at every zoom.
    static let stepFraction: CGFloat = 0.12

    /// Margin thresholds that raise the level by one each.
    private static let thresholds: [Double] = [1, 3, 6, 10]

    nonisolated static func level(userScore: Double, rivalScore: Double) -> Int {
        let margin = abs(userScore - rivalScore)
        var level = 0
        for threshold in thresholds where margin >= threshold {
            level += 1
        }
        return min(level, maxLevel)
    }
}
