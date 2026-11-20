import ASKCore
import Foundation

protocol HexTotalsProviding {
    func totals(for cell: HexCell) async throws -> HexInfo
}

extension AuthenticatedService: HexTotalsProviding {
    func totals(for cell: HexCell) async throws -> HexInfo {
        try await execute(request: HexTotalsRequest(cell: cell))
    }
}
