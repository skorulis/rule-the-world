import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class HexCellDetailViewModel {
    let cell: HexCell
    private(set) var visit: HexVisit?
    private(set) var visitCount = 0
    private(set) var totals: HexTotals?
    private(set) var isLoadingTotals = false

    private let store: HexVisitStore
    private let totalsProvider: (any HexTotalsProviding)?

    init(
        cell: HexCell, store: HexVisitStore, logStore: HexVisitLogStore,
        totalsProvider: (any HexTotalsProviding)? = nil
    ) {
        self.cell = cell
        self.store = store
        self.totalsProvider = totalsProvider
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
        guard let totalsProvider else { return }
        isLoadingTotals = true
        defer { isLoadingTotals = false }
        do {
            totals = try await totalsProvider.totals(for: cell)
        } catch {
            Logger().error("Hex totals lookup failed: \(error)")
        }
    }
}
