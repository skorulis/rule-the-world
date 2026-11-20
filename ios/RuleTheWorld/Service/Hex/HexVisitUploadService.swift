import ASKCore
import Foundation

extension AuthenticatedService {
    func upload(_ entries: [HexVisitLog]) async throws -> Set<String> {
        let response = try await execute(request: VisitBatchRequest(entries: entries))
        let accepted = Set(response.acceptedIds)
        guard accepted.isSubset(of: Set(entries.map(\.uploadID))), accepted.count == response.acceptedIds.count else {
            throw URLError(.cannotParseResponse)
        }
        return accepted
    }
}
