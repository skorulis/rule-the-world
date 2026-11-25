import ASKCore
import Foundation

protocol RegionLeadersProviding {
    func regionLeaders(type: RegionType, id: Int64) async throws -> [RegionLeader]
}

extension AuthenticatedService: RegionLeadersProviding {
    func regionLeaders(type: RegionType, id: Int64) async throws -> [RegionLeader] {
        try await execute(request: RegionLeadersRequest(type: type, id: id))
    }
}
