import Foundation

struct OnboardingPage: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let imageName: String

    static let pages: [OnboardingPage] = [
        OnboardingPage(
            id: 0,
            title: "Explore the world",
            subtitle: "Your real-world walks chart the map. "
                + "Every neighbourhood you visit is a hex waiting to be claimed.",
            imageName: "OnboardingExplore"
        ),
        OnboardingPage(
            id: 1,
            title: "Capture territory",
            subtitle: "Visit places to claim them as yours. "
                + "Hold the most territory and climb the ranks from Wanderer to King.",
            imageName: "OnboardingCapture"
        ),
        OnboardingPage(
            id: 2,
            title: "Power-up",
            subtitle: "Earn and deploy powerups to explore further, fortify your land, and outplay your rivals.",
            imageName: "OnboardingPowerUp"
        )
    ]
}
