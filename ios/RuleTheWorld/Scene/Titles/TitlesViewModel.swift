import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class TitlesViewModel {
    struct Item: Identifiable {
        let id: String
        let number: Int
        let type: String
        let ranks: [RankDefinition]
        let name: String
        let icon: String?
        let rarity: Rarity?
        let regionName: String
        let detail: String?
        let visited: Int?
        let owned: Int?
    }

    private let service: AuthenticatedService
    private let catalog: RankCatalog
    private let regionNames: RegionNameCatalog
    private(set) var items: [Item] = []
    private(set) var isLoading = false
    private(set) var hasLoaded = false
    private(set) var message: String?

    @Resolvable<Resolver>
    init(service: AuthenticatedService, catalog: RankCatalog, regionNames: RegionNameCatalog) {
        self.service = service
        self.catalog = catalog
        self.regionNames = regionNames
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let summary = try await service.fetchProfile()
            guard !Task.isCancelled else { return }
            var seen: Set<String> = []
            items = summary.rankings.sorted { $0.number < $1.number }.compactMap { ranking -> Item? in
                let id = "\(ranking.type):\(ranking.id)"
                guard seen.insert(id).inserted else { return nil }
                let definition = catalog.definition(for: ranking.number, type: ranking.type)
                return Item(
                    id: id,
                    number: ranking.number,
                    type: ranking.type,
                    ranks: catalog.definitions(for: ranking.type),
                    name: definition?.name ?? "Title #\(ranking.number)",
                    icon: definition?.icon,
                    rarity: definition?.rarity,
                    regionName: ranking.type == "global" ? "World" : (regionNames.name(for: ranking.id) ?? "Region #\(ranking.id)"),
                    detail: definition?.description,
                    visited: ranking.visited,
                    owned: ranking.owned
                )
            }.sorted { left, right in
                if left.number != right.number { return left.number < right.number }
                let comparison = left.regionName.localizedStandardCompare(right.regionName)
                return comparison == .orderedSame ? left.id < right.id : comparison == .orderedAscending
            }
            hasLoaded = true
            message = nil
        } catch {
            guard !Task.isCancelled else { return }
            message = "Couldn't load your titles. Please try again."
        }
    }
}
