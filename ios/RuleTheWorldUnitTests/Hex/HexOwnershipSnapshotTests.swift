import CoreLocation
import Foundation
import SwiftUI
import Testing
@testable import RuleTheWorld

struct HexOwnershipSnapshotTests {
    let grid = HexGridService()

    private var sydneyCell: HexCell {
        grid.cell(
            containing: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            resolution: HexGridService.baseResolution
        )
    }

    @Test func todayUsesGameCalendarAndPreservesState() {
        let midnight = HexVisit.scoringCalendar.startOfDay(for: Date(timeIntervalSince1970: 1_800_000_000))
        let info = HexInfo(
            cell: sydneyCell, totals: nil,
            userVisit: HexVisit(lastVisit: midnight, score: 0.5, lastScore: 0.5, total: 1)
        )
        let today = HexOwnershipSnapshot(infos: [info], at: midnight.addingTimeInterval(86_399))
        #expect(today.visitedToday == [sydneyCell])
        #expect(today.states[sydneyCell] == .partialVisit)
        let tomorrow = HexOwnershipSnapshot(infos: [info], at: midnight.addingTimeInterval(86_400))
        #expect(tomorrow.visitedToday.isEmpty)
        #expect(tomorrow.states == today.states)
        #expect(today != tomorrow)
        let yesterday = HexOwnershipSnapshot(infos: [info], at: midnight.addingTimeInterval(-1))
        #expect(yesterday.visitedToday.isEmpty)
    }

    @Test func missingVisitHasNoMarker() {
        let snapshot = HexOwnershipSnapshot(infos: [HexInfo(cell: sydneyCell, totals: nil, userVisit: nil)])
        #expect(snapshot.visitedToday.isEmpty)
        #expect(snapshot.states.isEmpty)
    }

    @Test func rivalOnlyCellIsRivalOwned() {
        let snapshot = HexOwnershipSnapshot(infos: [
            HexInfo(cell: sydneyCell, totals: HexTotals(totalVisits: 3, rivalScore: 2), userVisit: nil)
        ])
        #expect(snapshot.states[sydneyCell] == .rivalOwned)
        #expect(snapshot.visitedToday.isEmpty)
    }

    @Test func totalsWithoutRivalScoreHasNoState() {
        let snapshot = HexOwnershipSnapshot(infos: [
            HexInfo(cell: sydneyCell, totals: HexTotals(totalVisits: 0, rivalScore: 0), userVisit: nil)
        ])
        #expect(snapshot.states.isEmpty)
    }

    @Test func todayMarkersAggregateIndependentlyOfOwnership() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        let snapshot = HexOwnershipSnapshot(
            states: [children[0]: .owned, children[1]: .partialVisit, children[2]: .owned],
            visitedToday: [children[1], children[2]]
        )
        #expect(snapshot.aggregatedVisits(at: HexGridService.baseResolution, grid: grid) == snapshot.visitedToday)
        #expect(snapshot.aggregatedVisits(at: 7, grid: grid) == [parent])
        #expect(snapshot.aggregated(at: 7, grid: grid)[parent] == .owned)
    }

    @Test func ownershipAndVisitColors() {
        #expect(HexState.owned.color == Color.blue)
        #expect(HexState.visited.color == Color.blue)
        #expect(HexState.rivalOwned.color == Color.red)
        #expect(HexState.partialVisit.color == Color.cyan)
        #expect(HexState.explored.color == Color.mint)
        #expect(HexState.contested.color == Color.purple)
        #expect(HexState.unclaimed.color == nil)
    }

    @Test func stateForScore() {
        #expect(HexState.forScore(3.5, rivalScore: 1) == .owned)
        #expect(HexState.forScore(1, rivalScore: 3.5) == .rivalOwned)
        #expect(HexState.forScore(0.5, rivalScore: 1) == .rivalOwned)
        #expect(HexState.forScore(2, rivalScore: 2) == .contested)
        #expect(HexState.forScore(0.5, rivalScore: 0) == .partialVisit)
        #expect(HexState.forScore(0.5, rivalScore: 0.5) == .partialVisit)
        #expect(HexState.forScore(0, rivalScore: 0) == .partialVisit)
        #expect(HexState.forScore(3.5, rivalScore: nil) == .visited)
        #expect(HexState.forScore(0.5, rivalScore: nil) == .partialVisit)
        #expect(HexState.forScore(0, rivalScore: nil) == .partialVisit)
    }

    @Test func unvisitedScoreIsExploredUnlessOwned() {
        #expect(HexState.forScore(1, rivalScore: nil, hasVisited: false) == .explored)
        #expect(HexState.forScore(1, rivalScore: 3.5, hasVisited: false) == .rivalOwned)
        #expect(HexState.forScore(2, rivalScore: 2, hasVisited: false) == .explored)
        #expect(HexState.forScore(3.5, rivalScore: 1, hasVisited: false) == .owned)
    }

    @Test func visitWithNoOrganicVisitsMapsToExplored() {
        let info = HexInfo(
            cell: sydneyCell,
            totals: HexTotals(totalVisits: 0, rivalScore: 1),
            userVisit: HexVisit(lastVisit: .distantPast, score: 1, lastScore: 0, total: 0)
        )
        let snapshot = HexOwnershipSnapshot(infos: [info])
        #expect(snapshot.states[sydneyCell] == .explored)
        #expect(snapshot.visitedToday.isEmpty)
    }

    @Test func exploredCellWithLeadingRivalIsRivalOwned() {
        let info = HexInfo(
            cell: sydneyCell,
            totals: HexTotals(totalVisits: 0, rivalScore: 5),
            userVisit: HexVisit(lastVisit: .distantPast, score: 1, lastScore: 0, total: 0)
        )
        #expect(HexOwnershipSnapshot(infos: [info]).states[sydneyCell] == .rivalOwned)
    }

    @Test func aggregatedTiePrefersOwnStateOverRival() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        let snapshot = HexOwnershipSnapshot(states: [
            children[0]: .rivalOwned,
            children[1]: .owned,
        ])
        #expect(snapshot.aggregated(at: 7, grid: grid)[parent] == .owned)
    }

    @Test func baseResolutionAggregationReturnsStates() {
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        let snapshot = HexOwnershipSnapshot(states: [cell: .partialVisit])
        let aggregated = snapshot.aggregated(at: HexGridService.baseResolution, grid: grid)
        #expect(aggregated[cell] == .partialVisit)
    }

    @Test func aggregatedMajorityWins() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        var states: [HexCell: HexState] = [:]
        for child in children.prefix(4) {
            states[child] = .partialVisit
        }
        for child in children.dropFirst(4).prefix(2) {
            states[child] = .visited
        }
        let aggregated = HexOwnershipSnapshot(states: states).aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .partialVisit)
    }

    @Test func aggregatedTieGoesToStrongerState() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        let snapshot = HexOwnershipSnapshot(states: [
            children[0]: .partialVisit,
            children[1]: .visited,
        ])
        let aggregated = snapshot.aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .visited)
    }

    @Test func levelsComputedFromScoreMargin() {
        let snapshot = HexOwnershipSnapshot(infos: [
            HexInfo(
                cell: sydneyCell,
                totals: HexTotals(totalVisits: 5, rivalScore: 6),
                userVisit: HexVisit(lastVisit: .now, score: 10, lastScore: 1, total: 5),
            ),
        ])
        #expect(snapshot.levels[sydneyCell] == 3)
        #expect(snapshot.aggregatedWithLevels(at: HexGridService.baseResolution, grid: grid).levels[sydneyCell] == 3)
    }

    @Test func aggregatedLevelsTakeMaxOfChildren() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        let snapshot = HexOwnershipSnapshot(
            states: [children[0]: .owned, children[1]: .partialVisit],
            levels: [children[0]: 1, children[1]: 3]
        )
        let aggregated = snapshot.aggregatedWithLevels(at: 7, grid: grid)
        #expect(aggregated.levels[parent] == 3)
    }

    @Test func personalAggregationExcludesRivalLevels() {
        let rival = sydneyCell
        let snapshot = HexOwnershipSnapshot(
            states: [rival: .rivalOwned],
            levels: [rival: 4],
            visitLevels: [rival: 5]
        )
        let aggregated = snapshot.aggregatedPersonalWithLevels(at: HexGridService.baseResolution, grid: grid)
        #expect(aggregated.states.isEmpty)
        #expect(aggregated.levels.isEmpty)
    }

    @Test func personalLevelsUseVisitCountsNotMargin() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        let snapshot = HexOwnershipSnapshot(
            states: [children[0]: .owned, children[1]: .visited],
            levels: [children[0]: 4, children[1]: 4],
            visitLevels: [children[0]: 2, children[1]: 5]
        )
        let aggregated = snapshot.aggregatedPersonalWithLevels(at: 7, grid: grid)
        #expect(aggregated.levels[parent] == 5)
    }

    @Test func visitLevelsComputedFromVisitDays() {
        let snapshot = HexOwnershipSnapshot(infos: [
            HexInfo(
                cell: sydneyCell,
                totals: nil,
                userVisit: HexVisit(lastVisit: .now, score: 9, lastScore: 1, total: 12),
            ),
        ])
        #expect(snapshot.visitLevels[sydneyCell] == 5)
    }

    @Test func levelsAffectEquality() {
        let states: [HexCell: HexState] = [sydneyCell: .owned]
        #expect(
            HexOwnershipSnapshot(states: states)
                != HexOwnershipSnapshot(states: states, levels: [sydneyCell: 2])
        )
    }
}
