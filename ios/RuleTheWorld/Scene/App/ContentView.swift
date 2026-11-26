import ASKCoordinator
import ASKCore
import Knit
import SwiftUI

struct ContentView: View {
    @Environment(\.resolver) private var resolver
    @State var model: ContentViewModel

    var body: some View {
        CoordinatorView(coordinator: model.hexMapCoordinator)
            .withRenderers(resolver: resolver!)
            .onAppear { model.appeared() }
            .onDisappear { model.disappeared() }
    }
}
