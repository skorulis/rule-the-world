import ASKCoordinator
import ASKCore
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ContentViewModel {
    let hexMapCoordinator = Coordinator(root: MainPath.hexMap)
    let visitLogCoordinator = Coordinator(root: MainPath.visitLog)
    let profileCoordinator = Coordinator(root: MainPath.profile)

    @Resolvable<Resolver>
    init() {}
}
