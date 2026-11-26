import Foundation

struct HexOwnershipSnapshot: Sendable, nonisolated Equatable {
    nonisolated var states: [HexCell: HexState]
    nonisolated var levels: [HexCell: Int]
    nonisolated var visitedToday: Set<HexCell> = []

    nonisolated init(
        states: [HexCell: HexState],
        levels: [HexCell: Int] = [:],
        visitedToday: Set<HexCell> = []
    ) {
        self.states = states
        self.levels = levels
        self.visitedToday = visitedToday
    }

    nonisolated init(infos: [HexInfo], at date: Date = .now) {
        states = [:]
        levels = [:]
        for info in infos {
            if let visit = info.userVisit {
                states[info.cell] = HexState.forScore(
                    visit.score, rivalScore: info.totals?.rivalScore, hasVisited: visit.total > 0
                )
            } else if (info.totals?.rivalScore ?? 0) > 0 {
                states[info.cell] = .rivalOwned
            } else {
                continue
            }
            levels[info.cell] = HexElevationPolicy.level(
                userScore: info.userVisit?.score ?? 0,
                rivalScore: info.totals?.rivalScore ?? 0
            )
        }
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
        lhs.states == rhs.states && lhs.levels == rhs.levels && lhs.visitedToday == rhs.visitedToday
    }

    nonisolated func aggregated(at resolution: Int, grid: HexGridService) -> [HexCell: HexState] {
        aggregatedWithLevels(at: resolution, grid: grid).states
    }

    nonisolated func aggregatedPersonal(at resolution: Int, grid: HexGridService) -> [HexCell: HexState] {
        aggregatedPersonalWithLevels(at: resolution, grid: grid).states
    }

    nonisolated func aggregatedWithLevels(
        at resolution: Int, grid: HexGridService
    ) -> (states: [HexCell: HexState], levels: [HexCell: Int]) {
        Self.aggregate(states: states, levels: levels, at: resolution, grid: grid)
    }

    nonisolated func aggregatedPersonalWithLevels(
        at resolution: Int, grid: HexGridService
    ) -> (states: [HexCell: HexState], levels: [HexCell: Int]) {
        var personalLevels: [HexCell: Int] = [:]
        let personalStates = states.filter { key, value in
            if value != .rivalOwned {
                personalLevels[key] = levels[key]
                return true
            }
            return false
        }
        return Self.aggregate(states: personalStates, levels: personalLevels, at: resolution, grid: grid)
    }

    private nonisolated static func aggregate(
        states: [HexCell: HexState],
        levels: [HexCell: Int],
        at resolution: Int,
        grid: HexGridService
    ) -> (states: [HexCell: HexState], levels: [HexCell: Int]) {
        if resolution == HexGridService.baseResolution {
            return (states, levels)
        }
        var groups: [HexCell: [HexState: Int]] = [:]
        var levelGroups: [HexCell: Int] = [:]
        for (cell, state) in states {
            guard let parent = grid.parent(of: cell, at: resolution) else { continue }
            groups[parent, default: [:]][state, default: 0] += 1
            levelGroups[parent] = max(levelGroups[parent] ?? 0, levels[cell] ?? 0)
        }
        var result: [HexCell: HexState] = [:]
        for (parent, counts) in groups {
            result[parent] = Self.majorityState(counts: counts)
        }
        return (result, levelGroups)
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
