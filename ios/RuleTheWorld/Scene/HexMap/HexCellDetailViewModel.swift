import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class HexCellDetailViewModel {
    let cell: HexCell
    private(set) var info: HexInfo?
    private(set) var isLoadingTotals = false

    var visit: HexVisit? { info?.userVisit }
    var visitCount: Int { info?.userVisit?.total ?? 0 }

    private let store: HexInfoStore
    private let totalsProvider: (any HexTotalsProviding)?

    init(
        cell: HexCell, store: HexInfoStore, logStore: HexVisitLogStore,
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
            info = try await store.info(for: cell)
        } catch {
            Logger().error("Hex cell lookup failed: \(error)")
        }
        guard let totalsProvider else { return }
        isLoadingTotals = true
        defer { isLoadingTotals = false }
        do {
            for remote in try await totalsProvider.totals(for: [cell]) where remote.cell == cell {
                info = try await store.save(remote)
            }
        } catch {
            Logger().error("Hex totals lookup failed: \(error)")
        }
    }
}
