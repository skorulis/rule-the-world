import ASKCore
import Foundation
import Observation

@Observable
final class HexOwnershipStore {
    static let baseResolution = 9
    private static let storageKey = "hexOwnership.states"

    private let kvStore: PKeyValueStore

    private(set) var states: [HexCell: HexState] {
        didSet {
            aggregateCache = [:]
            persist()
        }
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
        if resolution == Self.baseResolution {
            aggregateCache[resolution] = states
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
        aggregateCache[resolution] = result
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

    private func persist() {
        let stored = StoredStates(states: states.reduce(into: [:]) { $0[$1.key.rawValue] = $1.value })
        try? kvStore.set(codable: stored, forKey: Self.storageKey)
    }

    private struct StoredStates: Codable {
        let states: [UInt64: HexState]
    }
}
