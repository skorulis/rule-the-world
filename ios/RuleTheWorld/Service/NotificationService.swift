import ASKCoordinator
import Foundation
import Observation

@Observable
@MainActor
final class NotificationService {
    typealias Presenter = (Coordinator, AppNotification, UUID) -> Void

    private weak var coordinator: Coordinator?
    private var pending: [AppNotification] = []
    private var sessionID = UUID()
    private(set) var activeNotificationID: UUID?
    private let present: Presenter
    @ObservationIgnored private var removeOverlay: (() -> Void)?

    var hasHost: Bool { coordinator != nil }

    init(present: @escaping Presenter = { coordinator, notification, sessionID in
        coordinator.custom(overlay: .notification, MainPath.notification(notification, sessionID))
    }) {
        self.present = present
    }

    func show(_ notification: AppNotification) {
        pending.append(notification)
        presentNext()
    }

    func attach(to coordinator: Coordinator) {
        guard self.coordinator !== coordinator else { return }
        self.coordinator = coordinator
        sessionID = UUID()
        activeNotificationID = nil
        removeCurrentOverlay()
        presentNext()
    }

    func detach(from coordinator: Coordinator) {
        guard self.coordinator === coordinator else { return }
        self.coordinator = nil
        sessionID = UUID()
        activeNotificationID = nil
        pending.removeAll()
        removeCurrentOverlay()
    }

    func overlayAppeared(id: UUID, sessionID: UUID, remove: @escaping () -> Void) -> Bool {
        guard self.sessionID == sessionID, activeNotificationID == id else { return false }
        removeOverlay = remove
        return true
    }

    func didDismiss(id: UUID, sessionID: UUID) {
        guard self.sessionID == sessionID, activeNotificationID == id else { return }
        pending.removeFirst()
        activeNotificationID = nil
        removeOverlay = nil
        presentNext()
    }

    private func removeCurrentOverlay() {
        let remove = removeOverlay
        removeOverlay = nil
        remove?()
    }

    private func presentNext() {
        guard activeNotificationID == nil, let coordinator, let next = pending.first else { return }
        activeNotificationID = next.id
        sessionID = UUID()
        present(coordinator, next, sessionID)
    }
}
