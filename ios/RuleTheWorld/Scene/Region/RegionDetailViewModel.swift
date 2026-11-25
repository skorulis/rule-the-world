import Foundation
import Observation
import OSLog

@Observable
@MainActor
final class RegionDetailViewModel {
    let region: MapRegionBoundary
    private(set) var leaders: [RegionLeader]?
    private(set) var isLoading = false
    private(set) var message: String?

    private let leadersProvider: (any RegionLeadersProviding)?
    private let catalog: RankCatalog

    init(
        region: MapRegionBoundary,
        leadersProvider: (any RegionLeadersProviding)? = nil,
        catalog: RankCatalog = RankCatalog()
    ) {
        self.region = region
        self.leadersProvider = leadersProvider
        self.catalog = catalog
    }

    func rankName(for leader: RegionLeader) -> String {
        catalog.definition(for: leader.rank, type: region.kind.name)?.name ?? "Rank #\(leader.rank)"
    }

    func load() async {
        guard !isLoading else { return }
        defer { isLoading = false }
        guard region.kind != .none && region.kind != .state,
              let id = Int64(region.id), id > 0,
              let leadersProvider else {
            leaders = []
            message = nil
            return
        }
        isLoading = true
        do {
            let fetched = try await leadersProvider.regionLeaders(type: region.kind, id: id)
            guard !Task.isCancelled else { return }
            leaders = fetched
            message = nil
        } catch {
            guard !Task.isCancelled else { return }
            Logger().error("Region leaders fetch failed: \(error)")
            message = "Couldn't load ranked users. Please try again."
        }
    }
}
