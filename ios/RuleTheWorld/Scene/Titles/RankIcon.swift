import SwiftUI

/// A generated badge icon for a rank, matching the power-up icon style.
/// Sources are hand-authored SVGs in ios/Icons, rasterized into the asset catalog.
struct RankIcon: View {
    let name: String
    var rarity: Rarity?
    var size: CGFloat = 56

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .overlay {
                if let rarity {
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .strokeBorder(rarity.color.opacity(0.8), lineWidth: 1.5)
                }
            }
            .shadow(color: rarity?.color.opacity(0.5) ?? .clear, radius: 4)
            .accessibilityHidden(true)
    }
}
