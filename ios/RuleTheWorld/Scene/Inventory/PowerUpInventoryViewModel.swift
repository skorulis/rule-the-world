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

        var name: String { definition?.displayName ?? "Unknown power-up #\(id)" }
        var rarity: Rarity? { definition?.rarity }
        var detail: String? { definition?.formattedDescription }
    }

    private let service: AuthenticatedService
    private let profileService: ProfileService
    private let catalog: PowerUpCatalog
    private let locationService: LocationService
    private let store: HexInfoStore
    private(set) var items: [Item] = []
    private(set) var isConsuming = false
    private(set) var message: String?

    @Resolvable<Resolver>
    init(
        service: AuthenticatedService,
        profileService: ProfileService,
        catalog: PowerUpCatalog,
        locationService: LocationService,
        store: HexInfoStore
    ) {
        self.service = service
        self.profileService = profileService
        self.catalog = catalog
        self.locationService = locationService
        self.store = store
    }

    var totalCount: Int {
        items.reduce(0) { $0 + $1.count }
    }

    func load() async {
        guard let summary = try? await profileService.fetchProfile(), !Task.isCancelled else { return }
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

    func consume(item: Item, location: LocationSample? = nil) async {
        guard !isConsuming, item.count > 0 else { return }
        guard let sample = location ?? locationService.latestSample else {
            message = "Location unavailable — try again when your position is known."
            return
        }
        isConsuming = true
        defer { isConsuming = false }
        do {
            let response = try await service.consumePowerUp(
                id: item.id,
                latitude: sample.latitude,
                longitude: sample.longitude
            )
            guard !Task.isCancelled else { return }
            try await store.restore(response.visits)
            let powerups = response.powerups
            items = items.compactMap { entry in
                let count = powerups[String(entry.id)] ?? 0
                return count > 0 ? Item(id: entry.id, definition: entry.definition, count: count) : nil
            }
            message = "\(item.name) applied."
        } catch let error as ConsumePowerUpFailure {
            message = error.error
        } catch {
            message = "Couldn't use \(item.name)."
        }
    }
}
