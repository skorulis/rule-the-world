import ASKCore
import Foundation
import Observation

@Observable
final class HexOwnershipStore {
    static let baseResolution = 10
    private static let storageKey = "hexOwnership.states"

    private let kvStore: PKeyValueStore

    private(set) var states: [HexCell: HexState] {
        didSet {
            aggregateCache = [:]
            persist()
        }
    }

    var snapshot: HexOwnershipSnapshot {
        HexOwnershipSnapshot(states: states)
    }

    private var aggregateCache: [Int: [HexCell: HexState]] = [:]

    init(kvStore: PKeyValueStore) {
        self.kvStore = kvStore
        let stored: StoredStates? = try? kvStore.codable(forKey: Self.storageKey)
        self.states = (stored?.states ?? [:]).reduce(into: [:]) { result, pair in
            result[HexCell(rawValue: pair.key)] = pair.value
        }
    }

    func state(for cell: HexCell) -> HexState {
        states[cell] ?? .unclaimed
    }

    func set(_ state: HexState, for cell: HexCell) {
        var updated = states
        if state == .unclaimed {
            updated[cell] = nil
        } else {
            updated[cell] = state
        }
        states = updated
    }

    func set(_ state: HexState, for cells: some Sequence<HexCell>) {
        var updated = states
        for cell in cells {
            if state == .unclaimed {
                updated[cell] = nil
            } else {
                updated[cell] = state
            }
        }
        states = updated
    }

    func toggle(_ cell: HexCell) {
        set(state(for: cell).next, for: cell)
    }

    func aggregated(at resolution: Int, grid: HexGridService) -> [HexCell: HexState] {
        if let cached = aggregateCache[resolution] {
            return cached
        }
        let result = snapshot.aggregated(at: resolution, grid: grid)
        aggregateCache[resolution] = result
        return result
    }

    private func persist() {
        let stored = StoredStates(states: states.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value })
        try? kvStore.set(codable: stored, forKey: Self.storageKey)
    }

    private struct StoredStates: Codable {
        let states: [UInt64: HexState]
    }
}
