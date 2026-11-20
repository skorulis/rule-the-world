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
    private let logStore: HexVisitLogStore

    init(cell: HexCell, store: HexVisitStore, logStore: HexVisitLogStore) {
        self.cell = cell
        self.store = store
        self.logStore = logStore
        Task {
            await load()
        }
    }

    func load() async {
        do {
            async let visit = store.visit(for: cell)
            async let count = logStore.visitCount(for: cell)
            (self.visit, visitCount) = try await (visit, count)
        } catch {
            Logger().error("Hex cell lookup failed: \(error)")
        }
    }
}
