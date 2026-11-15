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
    }

    @MainActor
    private func registerStores(container: Container<TargetResolver>) {
        container.register(HexOwnershipStore.self) { HexOwnershipStore(kvStore: $0.pKeyValueStore()) }
            .inObjectScope(.container)
    }

    @MainActor
    private func registerViewModels(container: Container<TargetResolver>) {
        container.register(ContentViewModel.self) { ContentViewModel.make(resolver: $0) }
        container.register(HexMapViewModel.self) { HexMapViewModel.make(resolver: $0) }
    }
}

extension RuleTheWorldAssembly {
    @MainActor static func testing() -> ScopedModuleAssembler<Resolver> {
        ScopedModuleAssembler<Resolver>([RuleTheWorldAssembly()])
    }
}
