import ASKCore
import Foundation

protocol HexTotalsProviding {
    func totals(for cells: [HexCell]) async throws -> [HexInfo]
}

extension AuthenticatedService: HexTotalsProviding {
    func totals(for cells: [HexCell]) async throws -> [HexInfo] {
        try await execute(request: HexTotalsRequest(cells: cells))
    }
}
