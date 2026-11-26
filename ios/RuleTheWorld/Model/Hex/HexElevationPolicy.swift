import Foundation

/// Quantizes the score margin on a hex into a discrete extrusion level for
/// the 3D map rendering. Higher levels mean a more decisive lead (in either
/// direction — color shows who is ahead).
enum HexElevationPolicy {
    static let maxLevel = 4

    /// Screen points of vertical lift per level.
    static let stepPoints: CGFloat = 7

    /// Margin thresholds that raise the level by one each.
    private static let thresholds: [Double] = [1, 3, 6, 10]

    static func level(userScore: Double, rivalScore: Double) -> Int {
        let margin = abs(userScore - rivalScore)
        var level = 0
        for threshold in thresholds where margin >= threshold {
            level += 1
        }
        return min(level, maxLevel)
    }
}
