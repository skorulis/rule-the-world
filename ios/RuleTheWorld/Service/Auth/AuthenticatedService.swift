import ASKCore
import Foundation

final class AuthenticatedService: HTTPService {
    private let tokenStore: AuthTokenStore

    init(
        tokenStore: AuthTokenStore,
        baseURL: String? = "http://localhost:3001",
        urlSession: URLSessionProtocol = URLSession(configuration: .default)
    ) {
        self.tokenStore = tokenStore
        super.init(baseURL: baseURL, logger: .init(level: .full), urlSession: urlSession)
    }

    func fetchProfile() async throws -> ProfileSummary {
        try await execute(request: ProfileRequest())
    }

    func addPowerUp() async throws -> AddPowerUpResponse {
        try await execute(request: AddPowerUpRequest())
    }

    func addMoney() async throws -> AddMoneyResponse {
        try await execute(request: AddMoneyRequest())
    }

    func claimDailyReward() async throws -> AddPowerUpResponse {
        try await execute(request: DailyRewardRequest())
    }

    func collectStipend() async throws -> StipendResponse {
        try await execute(request: StipendRequest())
    }

    func consumePowerUp(id: Int, latitude: Double, longitude: Double) async throws -> ConsumePowerUpResponse {
        try await execute(request: ConsumePowerUpRequest(powerup: id, latitude: latitude, longitude: longitude))
    }

    func purchaseLootBox(id: Int, count: Int) async throws -> LootBoxPurchaseResponse {
        try await execute(request: PurchaseLootBoxRequest(box: id, count: count))
    }

    func fetchVisits() async throws -> [HexInfo] {
        try await execute(request: VisitDownloadRequest())
    }

    override func modify(request: inout URLRequest) throws {
        try super.modify(request: &request)
        guard let token = tokenStore.token else {
            throw URLError(.userAuthenticationRequired)
        }
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    }
}
