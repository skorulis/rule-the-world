import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class OnboardingViewModel {
    var currentPage = 0

    let pages = OnboardingPage.pages

    var isLastPage: Bool {
        currentPage == pages.count - 1
    }

    var buttonTitle: String {
        isLastPage ? "Get started" : "Next"
    }

    func advance() {
        guard !isLastPage else { return }
        withAnimation {
            currentPage += 1
        }
    }
}
