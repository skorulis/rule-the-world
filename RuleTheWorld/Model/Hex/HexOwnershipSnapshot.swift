import Foundation

struct HexOwnershipSnapshot: Sendable, Equatable {
    var states: [HexCell: HexState]

    func aggregated(at resolution: Int, grid: HexGridService) -> [HexCell: HexState] {
        if resolution == HexOwnershipStore.baseResolution {
            return states
        }
        var groups: [HexCell: [HexState: Int]] = [:]
        for (cell, state) in states {
            guard let parent = grid.parent(of: cell, at: resolution) else { continue }
            groups[parent, default: [:]][state, default: 0] += 1
        }
        var result: [HexCell: HexState] = [:]
        for (parent, counts) in groups {
            result[parent] = Self.majorityState(counts: counts)
        }
        return result
    }

    private static func majorityState(counts: [HexState: Int]) -> HexState {
        var best: HexState = .mine
        var bestCount = -1
        for state in HexState.allCases where state != .unclaimed {
            let count = counts[state] ?? 0
            if count > bestCount {
                best = state
                bestCount = count
            }
        }
        return best
    }
}
