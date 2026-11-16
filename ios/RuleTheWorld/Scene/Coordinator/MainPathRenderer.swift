import ASKCoordinator
import Knit
import SwiftUI

struct MainPathRenderer: CoordinatorPathRenderer {
    typealias PathType = MainPath

    let resolver: Resolver

    @MainActor @ViewBuilder
    func render(path: MainPath, in coordinator: Coordinator) -> some View {
        switch path {
        case .content:
            ContentView(model: ContentViewModel.make(resolver: resolver))
        case .hexMap:
            HexMapView(model: HexMapViewModel.make(resolver: resolver))
        }
    }
}
