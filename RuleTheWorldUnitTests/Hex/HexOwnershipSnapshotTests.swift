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

    @Test func baseResolutionAggregationReturnsStates() {
        let cell = HexCell(rawValue: 0x8A283082876FFFF)
        let snapshot = HexOwnershipSnapshot(states: [cell: .neutral])
        let aggregated = snapshot.aggregated(at: HexGridService.baseResolution, grid: grid)
        #expect(aggregated[cell] == .neutral)
    }

    @Test func aggregatedMajorityWins() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        var states: [HexCell: HexState] = [:]
        for child in children.prefix(4) {
            states[child] = .mine
        }
        for child in children.dropFirst(4).prefix(2) {
            states[child] = .rival
        }
        let aggregated = HexOwnershipSnapshot(states: states).aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .mine)
    }

    @Test func aggregatedTieGoesToMine() {
        let parent = grid.parent(of: sydneyCell, at: 7)!
        let children = grid.children(of: parent, at: HexGridService.baseResolution)
        let snapshot = HexOwnershipSnapshot(states: [
            children[0]: .mine,
            children[1]: .rival,
        ])
        let aggregated = snapshot.aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .mine)
    }
}
