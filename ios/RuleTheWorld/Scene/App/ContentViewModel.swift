import ASKCoordinator
import ASKCore
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class ContentViewModel {
    let hexMapCoordinator = Coordinator(root: MainPath.hexMap)

    private let notificationService: NotificationService

    @Resolvable<Resolver>
    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    func appeared() {
        notificationService.attach(to: hexMapCoordinator)
    }

    func disappeared() {
        notificationService.detach(from: hexMapCoordinator)
    }
}
