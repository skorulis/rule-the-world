import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    struct Region: Identifiable {
        let id: Int64
        let name: String
        let visited: Int
        let owned: Int
    }

    private let authManager: AuthManager
    private let service: AuthenticatedService
    private let regionNames: RegionNameCatalog
    private let profileService: ProfileService
    let dailyReward: DailyRewardViewModel
    let stipend: StipendViewModel
    private(set) var visitedHexCount: Int?
    private(set) var ownedHexCount: Int?
    private(set) var coins: Int?
    private(set) var powerUpCount: Int?
    private(set) var titleCount: Int?
    private(set) var regions: [Region] = []

    @Resolvable<Resolver>
    init(
        authManager: AuthManager, service: AuthenticatedService,
        regionNames: RegionNameCatalog, profileService: ProfileService
    ) {
        self.authManager = authManager
        self.service = service
        self.regionNames = regionNames
        self.profileService = profileService
        self.dailyReward = DailyRewardViewModel(service: service, profileService: profileService)
        self.stipend = StipendViewModel(service: service, profileService: profileService)
    }

    func load() async {
        if let cached = profileService.cachedSummary {
            apply(cached)
        }
        guard let summary = try? await profileService.fetchProfile(), !Task.isCancelled else { return }
        apply(summary)
    }

    private func apply(_ summary: ProfileSummary) {
        visitedHexCount = summary.visited
        ownedHexCount = summary.owned
        powerUpCount = summary.powerups.values.reduce(0, +)
        titleCount = Set(summary.rankings.map { "\($0.type):\($0.id)" }).count
        dailyReward.update(availableAt: summary.dailyRewardAvailableAt)
        stipend.update(availableAt: summary.stipendAvailableAt, amount: summary.stipend)
        coins = summary.coins
        var seen: Set<Int64> = []
        regions = summary.regions.compactMap { region -> Region? in
            guard let name = regionNames.name(for: region.id), seen.insert(region.id).inserted else { return nil }
            return Region(id: region.id, name: name, visited: region.visited, owned: region.owned)
        }.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
        }
    }

    func applyInventory(_ powerups: [String: Int]) {
        powerUpCount = powerups.reduce(0) { total, entry in
            guard let id = Int(entry.key), id > 0, entry.value > 0 else { return total }
            return total + entry.value
        }
    }

    func applyCoins(_ value: Int) {
        coins = value >= 0 ? value : coins
    }

    func signOut() {
        authManager.signOut()
    }
}
