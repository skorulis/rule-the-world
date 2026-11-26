import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ProfileViewModel {
    private let authManager: AuthManager
    private let service: AuthenticatedService
    private let profileService: ProfileService
    private let bannerStore: BannerStore
    private(set) var banner: BannerConfiguration = .default
    private(set) var userID: String?
    var canEditBanner: Bool { userID != nil }
    let dailyReward: DailyRewardViewModel
    let stipend: StipendViewModel
    private(set) var visitedHexCount: Int?
    private(set) var ownedHexCount: Int?
    private(set) var coins: Int?
    private(set) var powerUpCount: Int?
    private(set) var titleCount: Int?
    private(set) var userName: String?

    @Resolvable<Resolver>
    init(
        authManager: AuthManager, service: AuthenticatedService,
        profileService: ProfileService, bannerStore: BannerStore
    ) {
        self.authManager = authManager
        self.service = service
        self.profileService = profileService
        self.bannerStore = bannerStore
        self.dailyReward = DailyRewardViewModel(service: service, profileService: profileService)
        self.stipend = StipendViewModel(service: service, profileService: profileService)
    }

    func load() async {
        refreshBanner()
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
        userName = summary.userName
        userID = summary.userID
        refreshBanner()
    }

    func refreshBanner() {
        banner = userID.map { bannerStore.banner(for: $0) } ?? .default
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
