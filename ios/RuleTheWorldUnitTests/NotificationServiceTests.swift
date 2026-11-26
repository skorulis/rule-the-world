import ASKCoordinator
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct NotificationServiceTests {
    private struct Presentation {
        let coordinator: Coordinator
        let notification: AppNotification
        let sessionID: UUID
    }

    private final class Recorder {
        var presentations: [Presentation] = []
    }

    private func makeService() -> (NotificationService, Recorder) {
        let recorder = Recorder()
        let service = NotificationService { coordinator, notification, sessionID in
            recorder.presentations.append(Presentation(
                coordinator: coordinator, notification: notification, sessionID: sessionID
            ))
        }
        return (service, recorder)
    }

    private func complete(_ presentation: Presentation, service: NotificationService) {
        service.didDismiss(id: presentation.notification.id, sessionID: presentation.sessionID)
    }

    @Test func queuesBeforeAttachmentAndPresentsInOrder() throws {
        let (service, recorder) = makeService()
        let first = AppNotification(title: "First", message: "One")
        let second = AppNotification(title: "Second", message: "Two")
        service.show(first)
        service.show(second)
        #expect(recorder.presentations.isEmpty)
        #expect(!service.hasHost)

        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        #expect(service.hasHost)
        #expect(recorder.presentations.map(\.notification.id) == [first.id])
        #expect(service.activeNotificationID == first.id)

        complete(try #require(recorder.presentations.first), service: service)
        #expect(recorder.presentations.map(\.notification.id) == [first.id, second.id])
        complete(try #require(recorder.presentations.last), service: service)
        #expect(service.activeNotificationID == nil)
    }

    @Test func duplicateAndUnknownCompletionsDoNotAdvanceQueue() throws {
        let (service, recorder) = makeService()
        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        service.show(AppNotification(title: "First", message: "One"))
        service.show(AppNotification(title: "Second", message: "Two"))
        service.show(AppNotification(title: "Third", message: "Three"))
        let first = try #require(recorder.presentations.first)
        service.didDismiss(id: UUID(), sessionID: first.sessionID)
        #expect(recorder.presentations.count == 1)
        complete(first, service: service)
        complete(first, service: service)
        #expect(recorder.presentations.count == 2)
        #expect(service.activeNotificationID == recorder.presentations.last?.notification.id)
    }

    @Test func identicalMessagesHaveUniquePaths() {
        let first = AppNotification(title: "Same", message: "Same")
        let second = AppNotification(title: "Same", message: "Same")
        let session = UUID()
        #expect(first.id != second.id)
        #expect(MainPath.notification(first, session).id != MainPath.notification(second, session).id)
    }

    @Test func reusingPayloadRejectsPreviousPresentationCompletion() throws {
        let (service, recorder) = makeService()
        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        let notification = AppNotification(title: "Same", message: "Same")
        service.show(notification)
        service.show(notification)
        let first = try #require(recorder.presentations.first)
        complete(first, service: service)
        let second = try #require(recorder.presentations.last)
        #expect(first.sessionID != second.sessionID)
        complete(first, service: service)
        #expect(service.activeNotificationID == notification.id)
        complete(second, service: service)
        #expect(service.activeNotificationID == nil)
    }

    @Test func repeatedAttachmentDoesNotPresentTwice() {
        let (service, recorder) = makeService()
        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        service.show(AppNotification(title: "First", message: "One"))
        service.attach(to: host)
        #expect(recorder.presentations.count == 1)
    }

    @Test func replacementHostRejectsOldCallbacksAndOldDetachment() throws {
        let (service, recorder) = makeService()
        let oldHost = Coordinator(root: MainPath.hexMap)
        let newHost = Coordinator(root: MainPath.hexMap)
        service.attach(to: oldHost)
        let notification = AppNotification(title: "First", message: "One")
        service.show(notification)
        let oldPresentation = try #require(recorder.presentations.first)
        var removed = false
        #expect(service.overlayAppeared(id: notification.id, sessionID: oldPresentation.sessionID) {
            removed = true
        })

        service.attach(to: newHost)
        #expect(removed)
        let newPresentation = try #require(recorder.presentations.last)
        #expect(newPresentation.coordinator === newHost)
        #expect(newPresentation.sessionID != oldPresentation.sessionID)
        #expect(newPresentation.notification.id == notification.id)
        service.detach(from: oldHost)
        complete(oldPresentation, service: service)
        #expect(service.hasHost)
        #expect(service.activeNotificationID == notification.id)
        #expect(!service.overlayAppeared(id: notification.id, sessionID: oldPresentation.sessionID, remove: {}))
        complete(newPresentation, service: service)
        #expect(service.activeNotificationID == nil)
    }

    @Test func teardownRemovesOverlayAndClearsQueue() throws {
        let (service, recorder) = makeService()
        let host = Coordinator(root: MainPath.hexMap)
        service.attach(to: host)
        service.show(AppNotification(title: "First", message: "One"))
        service.show(AppNotification(title: "Second", message: "Two"))
        let presentation = try #require(recorder.presentations.first)
        var removalCount = 0
        #expect(service.overlayAppeared(
            id: presentation.notification.id,
            sessionID: presentation.sessionID,
            remove: {
                removalCount += 1
                complete(presentation, service: service)
            }
        ))
        service.detach(from: host)
        #expect(removalCount == 1)
        #expect(!service.hasHost)
        #expect(service.activeNotificationID == nil)
        service.attach(to: host)
        #expect(recorder.presentations.count == 1)
        service.show(AppNotification(title: "Fresh", message: "New session"))
        #expect(recorder.presentations.count == 2)
    }
}
