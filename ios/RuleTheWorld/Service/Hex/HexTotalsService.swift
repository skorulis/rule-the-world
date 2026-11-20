import ASKCore
import Foundation

protocol HexTotalsProviding {
    func totals(for cell: HexCell) async throws -> HexTotals
}

extension AuthenticatedService: HexTotalsProviding {
    func totals(for cell: HexCell) async throws -> HexTotals {
        try await execute(request: HexTotalsRequest(cell: cell))
    }
}
