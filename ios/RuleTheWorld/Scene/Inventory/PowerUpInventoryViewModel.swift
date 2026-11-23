import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class PowerUpInventoryViewModel {
    struct Item: Identifiable {
        let id: Int
        let definition: PowerUpDefinition?
        let count: Int

        var name: String { definition?.name ?? "Unknown power-up #\(id)" }
        var rarity: PowerUpRarity? { definition?.rarity }
        var detail: String? { definition?.formattedDescription }
    }

    private let service: AuthenticatedService
    private let catalog: PowerUpCatalog
    private(set) var items: [Item] = []

    @Resolvable<Resolver>
    init(service: AuthenticatedService, catalog: PowerUpCatalog) {
        self.service = service
        self.catalog = catalog
    }

    func load() async {
        guard let summary = try? await service.fetchProfile(), !Task.isCancelled else { return }
        items = summary.powerups
            .map { Item(id: $0.key, definition: catalog.definition(for: $0.key), count: $0.value) }
            .sorted { lhs, rhs in
                switch (lhs.rarity, rhs.rarity) {
                case let (left?, right?) where left != right: return left < right
                case (_?, nil): return true
                case (nil, _?): return false
                default: return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
            }
    }
}
