import CoreLocation
import SwiftUI
import UIKit

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

struct LocationPermissionView: View {
    @Environment(\.openURL) private var openURL
    let locationService: LocationService

    private var isDenied: Bool {
        locationService.authorizationStatus == .denied
    }

    private var isRestricted: Bool {
        locationService.authorizationStatus == .restricted
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "location.circle.fill")
                .font(.system(size: 88))
                .foregroundStyle(.orange)
                .accessibilityHidden(true)

            Text("Your world starts here")
                .font(.largeTitle.bold())

            Text("""
                Rule the World uses your location to reveal the map, record the places you visit, \
                and help you capture territory as you explore.
                """)
                .foregroundStyle(.secondary)

            if isRestricted {
                Text("Location access is restricted on this device. Check your device restrictions to continue.")
                    .font(.callout)
            } else if isDenied {
                Text("Location access is turned off. Enable it for Rule the World in Settings to start exploring.")
                    .font(.callout)
            } else {
                Text("Next, your device will ask for location access. Allow access to start exploring.")
                    .font(.callout)
            }

            Spacer()

            Button {
                if isDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } else {
                    locationService.requestAuthorization()
                }
            } label: {
                Text(isDenied ? "Open Settings" : "Share location")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.orange)
            .disabled(isRestricted)
        }
        .multilineTextAlignment(.center)
        .padding(32)
    }
}
