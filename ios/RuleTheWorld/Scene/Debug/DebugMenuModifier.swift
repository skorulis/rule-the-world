import SwiftUI

/// Shows the debug settings sheet after a long press anywhere in the app.
struct DebugMenuModifier: ViewModifier {
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 2)
                    .onEnded { _ in isPresented = true }
            )
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    DebugSettingsView()
                }
            }
    }
}

extension View {
    func debugMenu() -> some View {
        modifier(DebugMenuModifier())
    }
}
