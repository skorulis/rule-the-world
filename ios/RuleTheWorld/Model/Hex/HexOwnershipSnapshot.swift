import Foundation

struct HexOwnershipSnapshot: Sendable, nonisolated Equatable {
    nonisolated var states: [HexCell: HexState]
    nonisolated var visitedToday: Set<HexCell> = []

    nonisolated init(states: [HexCell: HexState], visitedToday: Set<HexCell> = []) {
        self.states = states
        self.visitedToday = visitedToday
    }

    nonisolated init(infos: [HexInfo], at date: Date = .now) {
        states = Dictionary(uniqueKeysWithValues: infos.compactMap { info in
            info.userVisit.map {
                (info.cell, HexState.forScore($0.score, rivalScore: info.totals?.rivalScore, hasVisited: $0.total > 0))
            }
        })
        visitedToday = Set(infos.compactMap { info in
            guard let visit = info.userVisit,
                  HexVisit.scoringCalendar.isDate(visit.lastVisit, inSameDayAs: date) else { return nil }
            return info.cell
        })
    }

    nonisolated func aggregatedVisits(at resolution: Int, grid: HexGridService) -> Set<HexCell> {
        if resolution == HexGridService.baseResolution { return visitedToday }
        return Set(visitedToday.compactMap { grid.parent(of: $0, at: resolution) })
    }

    nonisolated static func == (lhs: HexOwnershipSnapshot, rhs: HexOwnershipSnapshot) -> Bool {
        lhs.states == rhs.states && lhs.visitedToday == rhs.visitedToday
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
