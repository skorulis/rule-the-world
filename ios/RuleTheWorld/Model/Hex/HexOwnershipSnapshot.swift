import Foundation

struct HexOwnershipSnapshot: Sendable, nonisolated Equatable {
    nonisolated var states: [HexCell: HexState]

    nonisolated static func == (lhs: HexOwnershipSnapshot, rhs: HexOwnershipSnapshot) -> Bool {
        lhs.states == rhs.states
    }

    nonisolated func aggregated(at resolution: Int, grid: HexGridService) -> [HexCell: HexState] {
        if resolution == HexGridService.baseResolution {
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

    private nonisolated static func majorityState(counts: [HexState: Int]) -> HexState {
        var best: HexState = .unclaimed
        var bestCount = 0
        for state in HexState.allCases where state != .unclaimed {
            let count = counts[state] ?? 0
            if count > bestCount || (count == bestCount && state > best) {
                best = state
                bestCount = count
            }
        }
        return best
    }
}
