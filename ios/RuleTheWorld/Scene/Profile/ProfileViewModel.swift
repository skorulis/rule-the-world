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
    let dailyReward: DailyRewardViewModel
    private(set) var visitedHexCount: Int?
    private(set) var ownedHexCount: Int?
    private(set) var powerUpCount: Int?
    private(set) var regions: [Region] = []

    @Resolvable<Resolver>
    init(authManager: AuthManager, service: AuthenticatedService, regionNames: RegionNameCatalog) {
        self.authManager = authManager
        self.service = service
        self.regionNames = regionNames
        self.dailyReward = DailyRewardViewModel(service: service)
    }

    func load() async {
        guard let summary = try? await service.fetchProfile(), !Task.isCancelled else { return }
        visitedHexCount = summary.visited
        ownedHexCount = summary.owned
        powerUpCount = summary.powerups.values.reduce(0, +)
        dailyReward.update(availableAt: summary.dailyRewardAvailableAt)
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

    func signOut() {
        authManager.signOut()
    }
}
