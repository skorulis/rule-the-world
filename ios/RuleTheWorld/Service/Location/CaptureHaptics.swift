import UIKit

/// Tactile feedback for recorded visits: a light tic for any visit and a
/// stronger confirmation when a visit makes the user the hex's owner.
@MainActor
protocol CaptureHaptics {
    func visitFeedback()
    func captureFeedback()
}

@MainActor
final class UICaptureHaptics: CaptureHaptics {
    private let visitGenerator = UIImpactFeedbackGenerator(style: .light)
    private let captureGenerator = UINotificationFeedbackGenerator()

    func visitFeedback() {
        visitGenerator.prepare()
        visitGenerator.impactOccurred()
    }

    func captureFeedback() {
        captureGenerator.prepare()
        captureGenerator.notificationOccurred(.success)
    }
}
