import ASKCoordinator
import Knit
import SwiftUI

struct MainPathRenderer: CoordinatorPathRenderer {
    typealias PathType = MainPath

    let resolver: Resolver

    @MainActor @ViewBuilder
    func render(path: MainPath, in coordinator: Coordinator) -> some View {
        switch path {
        case .signedOut:
            SignedOutView(loginModel: LoginViewModel.make(resolver: resolver))
        case .hexMap:
            HexMapView(
                model: HexMapViewModel.make(resolver: resolver),
                powerUpInventory: PowerUpInventoryViewModel.make(resolver: resolver)
            )
        case .visitLog:
            HexVisitLogListView(model: HexVisitLogListViewModel.make(resolver: resolver))
        case .profile:
            ProfileView(model: ProfileViewModel.make(resolver: resolver))
        case let .powerUpInventory(model):
            PowerUpInventoryView(model: model)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { coordinator.dismiss() }
                    }
                }
        case .titles:
            TitlesView(model: TitlesViewModel.make(resolver: resolver))
        case .shop:
            ShopView(model: ShopViewModel.make(resolver: resolver))
        }
    }
}
