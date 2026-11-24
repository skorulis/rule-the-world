import Foundation

enum HexInfoRefreshPolicy {
    static let staleInterval: TimeInterval = 24 * 3600
    static let maxCellsPerRequest = 500
    static let failureCooldown: TimeInterval = 30
}
