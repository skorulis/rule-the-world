import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class HexCellDetailViewModel {
    let cell: HexCell
    private(set) var visit: HexVisit?
    private(set) var visitCount = 0

    private let store: HexVisitStore

    init(cell: HexCell, store: HexVisitStore, logStore: HexVisitLogStore) {
        self.cell = cell
        self.store = store
        Task {
            await load()
        }
    }

    func load() async {
        do {
            visit = try await store.visit(for: cell)
            visitCount = visit?.total ?? 0
        } catch {
            Logger().error("Hex cell lookup failed: \(error)")
        }
    }
}
