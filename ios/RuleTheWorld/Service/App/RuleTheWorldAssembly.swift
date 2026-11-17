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
        container.register(HexGridService.self) { _ in HexGridService() }
            .inObjectScope(.container)
        container.register(LocationService.self) { _ in LocationService() }
            .inObjectScope(.container)
        container.register(LocationCaptureService.self) {
            LocationCaptureService(
                grid: $0.hexGridService(),
                store: $0.hexVisitStore(),
                logStore: $0.hexVisitLogStore()
            )
        }
        .inObjectScope(.container)
        container.register(AuthService.self) { _ in AuthService() }
            .inObjectScope(.container)
        container.register(AuthTokenStore.self) {
            AuthTokenStore(keyValueStore: $0.secureKeyValueStore())
        }
        .inObjectScope(.container)
        container.register(AuthManager.self) {
            AuthManager(service: $0.authService(), tokenStore: $0.authTokenStore())
        }
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
        container.register(HexVisitStore.self) { HexVisitStore(database: $0.appDatabase()) }
            .inObjectScope(.container)
        container.register(HexVisitLogStore.self) { HexVisitLogStore(database: $0.appDatabase()) }
            .inObjectScope(.container)
    }

    @MainActor
    private func registerViewModels(container: Container<TargetResolver>) {
        container.register(ContentViewModel.self) { ContentViewModel.make(resolver: $0) }
        container.register(LoginViewModel.self) { LoginViewModel.make(resolver: $0) }
        container.register(HexMapViewModel.self) { HexMapViewModel.make(resolver: $0) }
        container.register(HexVisitLogListViewModel.self) { HexVisitLogListViewModel.make(resolver: $0) }
    }
}

extension RuleTheWorldAssembly {
    @MainActor static func testing() -> ScopedModuleAssembler<Resolver> {
        ScopedModuleAssembler<Resolver>([RuleTheWorldAssembly()])
    }
}
