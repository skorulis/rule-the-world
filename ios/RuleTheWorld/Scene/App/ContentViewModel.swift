import ASKCoordinator
import ASKCore
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ContentViewModel {
    let hexMapCoordinator = Coordinator(root: MainPath.hexMap)

    @Resolvable<Resolver>
    init() {}
}
