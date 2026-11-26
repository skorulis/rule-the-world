import SwiftUI

/// In-app notification banner for transient messages shown while exploring,
/// e.g. "You have gained the Duke rank in Australia". Optionally tinted by a
/// `Rarity`, which colors the label, card chrome and icon ring.
struct NotificationBanner: View {
    /// Small uppercase label above the message, e.g. "New rank!".
    let title: String
    /// The notification body text.
    let message: String
    /// Optional asset-catalog icon shown on the leading edge.
    var icon: String?
    var rarity: Rarity?

    var body: some View {
        HStack(spacing: 12) {
            if let icon {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 44)
                    .overlay {
                        if let rarity {
                            RoundedRectangle(cornerRadius: 44 * 0.22, style: .continuous)
                                .strokeBorder(rarity.color.opacity(0.8), lineWidth: 1.5)
                        }
                    }
                    .shadow(color: rarity?.color.opacity(0.5) ?? .clear, radius: 4)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(rarity?.color ?? .secondary)
                    .textCase(.uppercase)
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .gameCard(rarity: rarity, fallback: .accentColor)
        .padding(.horizontal)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Common") {
    NotificationBanner(
        title: "New rank!",
        message: "You have gained the Burgess rank in Australia",
        icon: "rank-burgess",
        rarity: .common
    )
}

#Preview("Legendary") {
    NotificationBanner(
        title: "New rank!",
        message: "You have gained the Duke rank in Australia",
        icon: "rank-duke",
        rarity: .legendary
    )
}

#Preview("Plain") {
    NotificationBanner(
        title: "Exploration",
        message: "You discovered a new region"
    )
}
