import CoreLocation
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

    @Test func stateForScore() {
        #expect(HexState.forScore(3.5, rivalScore: 1) == .owned)
        #expect(HexState.forScore(1, rivalScore: 3.5) == .visited)
        #expect(HexState.forScore(2, rivalScore: 2) == .contested)
        #expect(HexState.forScore(0, rivalScore: 0) == .contested)
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
