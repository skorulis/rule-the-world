import SwiftUI

/// Shows the debug settings sheet after a long press anywhere in the app.
struct DebugMenuModifier: ViewModifier {
    @State private var isPresented = false
    let locationService: LocationService?
    let captureService: LocationCaptureService?

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 2)
                    .onEnded { _ in isPresented = true }
            )
            .sheet(isPresented: $isPresented) {
                NavigationStack {
                    DebugSettingsView(locationService: locationService, captureService: captureService)
                }
            }
    }
}

extension View {
    func debugMenu(locationService: LocationService?, captureService: LocationCaptureService?) -> some View {
        modifier(DebugMenuModifier(locationService: locationService, captureService: captureService))
    }
}
