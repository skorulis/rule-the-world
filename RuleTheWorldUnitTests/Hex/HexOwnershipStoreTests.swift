import CoreLocation

import ASKCore
import Testing
@testable import RuleTheWorld

struct HexOwnershipStoreTests {
    let grid = HexGridService()

    private func makeStore() -> HexOwnershipStore {
        HexOwnershipStore(kvStore: InMemoryKeyValueStore())
    }

    @Test func toggleCyclesThroughStates() {
        let store = makeStore()
        let cell = HexCell(rawValue: 0x8928308280FFFFF)
        #expect(store.state(for: cell) == .unclaimed)
        store.toggle(cell)
        #expect(store.state(for: cell) == .mine)
        store.toggle(cell)
        #expect(store.state(for: cell) == .rival)
        store.toggle(cell)
        #expect(store.state(for: cell) == .neutral)
        store.toggle(cell)
        #expect(store.state(for: cell) == .unclaimed)
    }

    @Test func persistenceRoundTrip() {
        let kvStore = InMemoryKeyValueStore()
        let cell = HexCell(rawValue: 0x8928308280FFFFF)
        let store = HexOwnershipStore(kvStore: kvStore)
        store.set(.rival, for: cell)

        let reloaded = HexOwnershipStore(kvStore: kvStore)
        #expect(reloaded.state(for: cell) == .rival)
    }

    @Test func aggregatedMajorityWins() {
        let store = makeStore()
        let coordinate = CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19)
        let cell = grid.cell(containing: coordinate, resolution: 9)
        let parent = grid.parent(of: cell, at: 7)!
        let children = grid.children(of: parent, at: 9)

        for child in children.prefix(4) {
            store.set(.mine, for: child)
        }
        for child in children.dropFirst(4).prefix(2) {
            store.set(.rival, for: child)
        }

        let aggregated = store.aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .mine)
    }

    @Test func aggregatedTieGoesToMine() {
        let store = makeStore()
        let coordinate = CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19)
        let cell = grid.cell(containing: coordinate, resolution: 9)
        let parent = grid.parent(of: cell, at: 7)!
        let children = grid.children(of: parent, at: 9)

        store.set(.mine, for: children[0])
        store.set(.rival, for: children[1])

        let aggregated = store.aggregated(at: 7, grid: grid)
        #expect(aggregated[parent] == .mine)
    }

    @Test func batchSetPersistsAllCells() {
        let kvStore = InMemoryKeyValueStore()
        let coordinate = CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19)
        let cell = grid.cell(containing: coordinate, resolution: 9)
        let parent = grid.parent(of: cell, at: 7)!
        let children = grid.children(of: parent, at: 9)

        let store = HexOwnershipStore(kvStore: kvStore)
        store.set(.rival, for: children)

        let reloaded = HexOwnershipStore(kvStore: kvStore)
        #expect(children.count >= 7)
        for child in children {
            #expect(reloaded.state(for: child) == .rival)
        }
    }

    @Test func baseResolutionAggregationReturnsStates() {
        let store = makeStore()
        let cell = HexCell(rawValue: 0x8928308280FFFFF)
        store.set(.neutral, for: cell)
        let aggregated = store.aggregated(at: 9, grid: grid)
        #expect(aggregated[cell] == .neutral)
    }
}
