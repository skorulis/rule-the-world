import ASKCoordinator
import Knit
import SwiftUI

extension CoordinatorView {
    func withRenderers(resolver: Resolver) -> Self {
        self.with(renderer: resolver.mainPathRenderer())
            .with(overlay: .notification) { view, path in
                guard let path = path as? MainPath,
                      case let .notification(notification, sessionID) = path else {
                    preconditionFailure("Notification overlay requires a notification path")
                }
                return AnyView(NotificationPathWrapper(
                    notificationID: notification.id,
                    sessionID: sessionID,
                    service: resolver.notificationService(),
                    content: view
                ))
            }
    }
}
