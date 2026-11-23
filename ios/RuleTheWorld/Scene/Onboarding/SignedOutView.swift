import SwiftUI

/// Root shown while signed out: onboarding slides first, then the login screen.
struct SignedOutView: View {
    @State private var showOnboarding = true
    let loginModel: LoginViewModel

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(model: OnboardingViewModel()) {
                    withAnimation { showOnboarding = false }
                }
            } else {
                LoginView(model: loginModel)
            }
        }
    }
}
