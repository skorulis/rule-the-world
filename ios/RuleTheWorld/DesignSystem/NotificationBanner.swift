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
        ParchmentPanel(
            style: .thin(borderColor: rarity?.color ?? Color(red: 0.35, green: 0.22, blue: 0.13)),
            contentInsets: EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
        ) {
            HStack(spacing: 12) {
                if let icon {
                    Image(icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 44, height: 44)
                        .overlay {
                            if let rarity {
                                RoundedRectangle(cornerRadius: 44 * 0.22, style: .continuous)
                                    .strokeBorder(rarity.color, lineWidth: 2)
                            }
                        }
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(Color(red: 0.35, green: 0.22, blue: 0.13))
                        .textCase(.uppercase)
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color(red: 0.18, green: 0.13, blue: 0.12))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
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
