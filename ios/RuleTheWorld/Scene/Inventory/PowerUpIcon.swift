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
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .strokeBorder(color.opacity(0.8), lineWidth: 1.5)
            }
            .shadow(color: color.opacity(0.5), radius: 4)
            .accessibilityHidden(true)
    }

    private var image: Image {
        switch type {
        case .revisit: Image("PowerUpRevisit")
        case .exploration: Image("PowerUpExploration")
        case .fortification: Image("PowerUpFortification")
        case .attack: Image(systemName: "bolt.shield.fill")
        }
    }

    private var color: Color { rarity?.color ?? .secondary }
}
