import ASKCoordinator
import Knit
import SwiftUI

struct MainPathRenderer: CoordinatorPathRenderer {
    typealias PathType = MainPath

    let resolver: Resolver

    @MainActor @ViewBuilder
    func render(path: MainPath, in coordinator: Coordinator) -> some View {
        switch path {
        case .hexMap:
            HexMapView(model: HexMapViewModel.make(resolver: resolver))
        case .visitLog:
            HexVisitLogListView(model: HexVisitLogListViewModel.make(resolver: resolver))
        case .profile:
            ProfileView(model: ProfileViewModel.make(resolver: resolver))
        case .titles:
            TitlesView(model: TitlesViewModel.make(resolver: resolver))
        case .powerUpInventory:
            PowerUpInventoryView(model: PowerUpInventoryViewModel.make(resolver: resolver))
        }
    }
}
