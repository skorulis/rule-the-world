import ASKCore
import Knit
import SwiftUI

/// Shows the debug settings sheet after a long press anywhere in the app.
struct DebugMenuModifier: ViewModifier {
    @State private var isPresented = false
    let resolver: Resolver

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 2)
                    .onEnded { _ in isPresented = true }
            )
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    DebugSettingsView(model: resolver.debugSettingsViewModel())
                }
            }
    }
}

extension View {
    func debugMenu(resolver: Resolver) -> some View {
        modifier(DebugMenuModifier(resolver: resolver))
    }
}
