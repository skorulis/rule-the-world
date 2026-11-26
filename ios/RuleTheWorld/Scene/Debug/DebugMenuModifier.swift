import ASKCore
import Knit
import SwiftUI

/// Shows the debug settings sheet after a long press anywhere in the app.
struct DebugMenuModifier: ViewModifier {
    @State private var isPresented = false
    @State private var pendingNotifications: (() -> Void)?
    let resolver: Resolver

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 2)
                    .onEnded { _ in isPresented = true }
            )
            .sheet(isPresented: $isPresented, onDismiss: presentPendingNotifications) {
                NavigationStack {
                    let model = resolver.debugSettingsViewModel()
                    DebugSettingsView(model: model) { queued in
                        pendingNotifications = { model.showSampleNotifications(queued: queued) }
                        isPresented = false
                    }
                }
            }
    }

    private func presentPendingNotifications() {
        let action = pendingNotifications
        pendingNotifications = nil
        action?()
    }
}

extension View {
    func debugMenu(resolver: Resolver) -> some View {
        modifier(DebugMenuModifier(resolver: resolver))
    }
}
