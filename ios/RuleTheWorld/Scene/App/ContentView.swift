import ASKCoordinator
import ASKCore
import Knit
import SwiftUI

struct ContentView: View {
    @Environment(\.resolver) private var resolver
    @State var model: ContentViewModel

    var body: some View {
        TabView {
            Tab("Map", systemImage: "map") {
                CoordinatorView(coordinator: model.hexMapCoordinator)
                    .withRenderers(resolver: resolver!)
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                CoordinatorView(coordinator: model.profileCoordinator)
                    .withRenderers(resolver: resolver!)
            }
        }
    }
}
