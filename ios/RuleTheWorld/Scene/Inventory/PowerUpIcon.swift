import SwiftUI

/// A generated icon for the power-up type, framed by a rarity-tinted ring.
/// Sources are hand-authored SVGs in ios/Icons, rasterized into the asset catalog.
struct PowerUpIcon: View {
    let type: PowerUpType
    let rarity: Rarity?
    var size: CGFloat = 56

    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .background {
                Circle()
                    .fill(color.opacity(0.3))
                    .padding(size * 0.1)
                    .blur(radius: size * 0.14)
            }
            .shadow(color: color.opacity(0.5), radius: 4)
            .accessibilityHidden(true)
    }

    private var image: Image {
        switch type {
        case .attack: Image("PowerUpAttack")
        case .defend: Image("PowerUpFortification")
        case .explore: Image("PowerUpExploration")
        }
    }

    private var color: Color { rarity?.color ?? .secondary }
}
