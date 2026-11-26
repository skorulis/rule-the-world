import ASKCoordinator
import SwiftUI

extension CustomOverlay.Name {
    static let notification = CustomOverlay.Name("notification")
}

struct NotificationPathWrapper<Content: View>: View {
    let notificationID: UUID
    let sessionID: UUID
    let service: NotificationService
    let content: Content

    @Environment(\.dismissCustomOverlay) private var dismissOverlay
    @Environment(\.customOverlayVisible) private var overlayVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDismissing = false
    @State private var isFinished = false

    private var visible: Bool { overlayVisible && !isDismissing }
    private var animation: Animation { .easeInOut(duration: 0.25) }

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            if visible {
                Button(action: dismiss) {
                    content
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(animation, value: overlayVisible)
        .task {
            guard service.overlayAppeared(id: notificationID, sessionID: sessionID, remove: dismissOverlay) else {
                finish()
                return
            }
            do {
                try await Task.sleep(for: .seconds(5))
            } catch {
                return
            }
            dismiss()
        }
        .onDisappear(perform: finish)
    }

    private func dismiss() {
        guard !isDismissing, !isFinished else { return }
        withAnimation(animation, completionCriteria: .removed) {
            isDismissing = true
        } completion: {
            finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        dismissOverlay()
        service.didDismiss(id: notificationID, sessionID: sessionID)
    }
}
