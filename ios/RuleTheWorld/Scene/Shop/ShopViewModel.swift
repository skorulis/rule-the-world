import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ShopViewModel {
    struct OpenedBox: Identifiable {
        let id = UUID()
        let rewards: [PowerUpDefinition]

        var summary: String {
            rewards.reduce(into: [:]) { $0[$1.displayName, default: 0] += 1 }
                .sorted { $0.key < $1.key }
                .map { $0.value > 1 ? "\($0.key) ×\($0.value)" : $0.key }
                .joined(separator: "\n")
        }
    }

    private let service: AuthenticatedService
    private let profileService: ProfileService
    let boxes: [LootBoxDefinition]
    private(set) var coins: Int?
    private(set) var isPurchasing = false
    private(set) var errorMessage: String?
    var openedBox: OpenedBox?

    @Resolvable<Resolver>
    init(service: AuthenticatedService, profileService: ProfileService, lootBoxes: LootBoxCatalog) {
        self.service = service
        self.profileService = profileService
        self.boxes = lootBoxes.all
    }

    func load() async {
        coins = profileService.cachedSummary?.coins ?? coins
        guard let summary = try? await profileService.fetchProfile(), !Task.isCancelled else { return }
        coins = summary.coins
    }

    func canAfford(_ box: LootBoxDefinition, count: Int) -> Bool {
        (coins ?? 0) >= box.cost * count
    }

    func purchase(box: LootBoxDefinition, count: Int) async {
        guard !isPurchasing, count > 0 else { return }
        isPurchasing = true
        errorMessage = nil
        defer { isPurchasing = false }
        do {
            let response = try await service.purchaseLootBox(id: box.id, count: count)
            guard !Task.isCancelled else { return }
            coins = response.coins
            openedBox = OpenedBox(rewards: response.rewards)
        } catch let error as LootBoxPurchaseFailure {
            errorMessage = error.error
        } catch {
            errorMessage = "Couldn't buy \(box.name)."
        }
    }
}
