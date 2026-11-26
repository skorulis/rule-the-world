import ASKCore
import Foundation
import Knit
import KnitMacros
import SwiftUI

final class RuleTheWorldAssembly: AutoInitModuleAssembly {
    static var dependencies: [any Knit.ModuleAssembly.Type] = []
    typealias TargetResolver = Resolver

    private let purpose: IOCPurpose

    init() {
        self.purpose = .testing
    }

    init(purpose: IOCPurpose) {
        self.purpose = purpose
    }

    @MainActor func assemble(container: Container<TargetResolver>) {
        ASKCoreAssembly(purpose: purpose).assemble(container: container)

        container.register(MainPathRenderer.self) { MainPathRenderer(resolver: $0) }

        registerServices(container: container)
        registerStores(container: container)
        registerViewModels(container: container)
    }

    @MainActor
    private func registerServices(container: Container<TargetResolver>) {
        let endpoint = DebugSettings().endpoint

        registerSupportServices(container: container)
        container.register(LocationCaptureService.self) { resolver in
            LocationCaptureService(
                grid: resolver.hexGridService(),
                store: resolver.hexInfoStore(),
                logStore: resolver.hexVisitLogStore(),
                onNewDailyHex: resolver.hexVisitSyncService().requestImmediateSync
            )
        }
        .inObjectScope(.container)
        container.register(URLSessionProtocol.self) { _ in
            endpoint.makeSession()
        }
        .inObjectScope(.container)
        container.register(AuthService.self) {
            AuthService(baseURL: endpoint.baseURL, urlSession: $0.urlSessionProtocol())
        }
        .inObjectScope(.container)
        container.register(AuthenticatedService.self) {
            AuthenticatedService(
                tokenStore: $0.authTokenStore(),
                baseURL: endpoint.baseURL,
                urlSession: $0.urlSessionProtocol()
            )
        }
        .inObjectScope(.container)
        container.register(HexTotalsProviding.self) { $0.authenticatedService() }
        .inObjectScope(.container)
        container.register(RegionLeadersProviding.self) { $0.authenticatedService() }
        .inObjectScope(.container)
        container.register(ProfileService.self) {
            ProfileService(service: $0.authenticatedService(), store: $0.profileSummaryStore())
        }
        .inObjectScope(.container)
        container.register(HexVisitSyncService.self) {
            HexVisitSyncService(
                store: $0.hexVisitLogStore(),
                hexInfoStore: $0.hexInfoStore(),
                uploader: $0.authenticatedService(),
                tokenStore: $0.authTokenStore(),
                profileStore: $0.profileSummaryStore(),
                notificationService: $0.notificationService(),
                titleNotifications: TitleNotificationBuilder(
                    catalog: $0.rankCatalog(), regionNames: $0.regionNameCatalog()
                )
            )
        }
        .inObjectScope(.container)
        container.register(AuthTokenStore.self) {
            AuthTokenStore(keyValueStore: $0.secureKeyValueStore())
        }
        .inObjectScope(.container)
        container.register(AuthManager.self) {
            AuthManager(
                service: $0.authService(),
                authenticatedService: $0.authenticatedService(),
                tokenStore: $0.authTokenStore(),
                database: $0.appDatabase(),
                visitStore: $0.hexInfoStore(),
                profileStore: $0.profileSummaryStore()
            )
        }
        .inObjectScope(.container)
    }

    @MainActor
    private func registerSupportServices(container: Container<TargetResolver>) {
        container.register(NotificationService.self) { _ in NotificationService() }
            .inObjectScope(.container)
        container.register(HexGridService.self) { _ in HexGridService() }
            .inObjectScope(.container)
        container.register(RegionNameCatalog.self) { _ in RegionNameCatalog() }
            .inObjectScope(.container)
        container.register(PowerUpCatalog.self) { _ in PowerUpCatalog() }
            .inObjectScope(.container)
        container.register(LootBoxCatalog.self) { _ in LootBoxCatalog() }
            .inObjectScope(.container)
        container.register(RankCatalog.self) { _ in RankCatalog() }
            .inObjectScope(.container)
        container.register(RegionBoundaryProviding.self) { _ in RegionBoundaryService() }
            .inObjectScope(.container)
        container.register(LocationService.self) { _ in LocationService() }
            .inObjectScope(.container)
    }

    @MainActor
    private func registerStores(container: Container<TargetResolver>) {
        container.register(AppDatabase.self) { _ in
            do {
                return try self.purpose == .testing ? AppDatabase.inMemory() : AppDatabase.onDisk()
            } catch {
                fatalError("Failed to open database: \(error)")
            }
        }
        .inObjectScope(.container)
        container.register(HexInfoStore.self) { HexInfoStore(database: $0.appDatabase()) }
            .inObjectScope(.container)
        container.register(HexVisitLogStore.self) { HexVisitLogStore(database: $0.appDatabase()) }
            .inObjectScope(.container)
        container.register(ProfileSummaryStore.self) { ProfileSummaryStore(keyValueStore: $0.pKeyValueStore()) }
            .inObjectScope(.container)
        container.register(BannerStore.self) { BannerStore(keyValueStore: $0.pKeyValueStore()) }
            .inObjectScope(.container)
    }

    @MainActor
    private func registerViewModels(container: Container<TargetResolver>) {
        container.register(ContentViewModel.self) { ContentViewModel.make(resolver: $0) }
        container.register(LoginViewModel.self) { LoginViewModel.make(resolver: $0) }
        container.register(HexMapViewModel.self) { HexMapViewModel.make(resolver: $0) }
        container.register(HexVisitLogListViewModel.self) { HexVisitLogListViewModel.make(resolver: $0) }
        container.register(ProfileViewModel.self) { ProfileViewModel.make(resolver: $0) }
        container.register(BannerEditorViewModel.self) { (resolver: Resolver, userID: String) in
            BannerEditorViewModel.make(resolver: resolver, userID: userID)
        }
        container.register(TitlesViewModel.self) { TitlesViewModel.make(resolver: $0) }
        container.register(ShopViewModel.self) { ShopViewModel.make(resolver: $0) }
        container.register(PowerUpInventoryViewModel.self) { PowerUpInventoryViewModel.make(resolver: $0) }
        container.register(DebugSettingsViewModel.self) { DebugSettingsViewModel.make(resolver: $0) }
    }
}

extension RuleTheWorldAssembly {
    @MainActor static func testing() -> ScopedModuleAssembler<Resolver> {
        ScopedModuleAssembler<Resolver>([RuleTheWorldAssembly()])
    }
}
