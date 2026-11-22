import CoreLocation
import Foundation
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
            userVisit: HexVisit(lastVisit: midnight, score: 0.5, lastScore: 0.5)
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

    @Test func stateForScore() {
        #expect(HexState.forScore(3.5, rivalScore: 1) == .owned)
        #expect(HexState.forScore(1, rivalScore: 3.5) == .visited)
        #expect(HexState.forScore(2, rivalScore: 2) == .contested)
        #expect(HexState.forScore(0.5, rivalScore: 0) == .partialVisit)
        #expect(HexState.forScore(0.5, rivalScore: 0.5) == .partialVisit)
        #expect(HexState.forScore(0, rivalScore: 0) == .partialVisit)
        #expect(HexState.forScore(3.5, rivalScore: nil) == .visited)
        #expect(HexState.forScore(0.5, rivalScore: nil) == .partialVisit)
        #expect(HexState.forScore(0, rivalScore: nil) == .partialVisit)
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
            children[1]: .visited
        ])
        let aggregated = snapshot.aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .visited)
    }
}
