import SwiftUI

/// A "loot card" cell for a power-up: rarity is conveyed by the card's
/// border, tint and glow instead of a text label.
struct PowerUpCard: View {
    let item: PowerUpInventoryViewModel.Item
    let isConsuming: Bool
    let onUse: () -> Void

    private var rarity: PowerUpRarity? { item.rarity }
    private var color: Color { rarity?.color ?? .secondary }
    private var isEpic: Bool { rarity == .epic }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let type = item.definition?.type {
                PowerUpIcon(type: type, rarity: rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name).font(.headline)
                    Spacer()
                    Text("×\(item.count)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(color)
                }
                if let detail = item.detail {
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack {
                    Spacer()
                    Button("Use", action: onUse)
                        .buttonStyle(.borderedProminent)
                        .tint(isEpic ? .purple : nil)
                        .disabled(isConsuming || item.count < 1)
                }
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(isEpic ? 0.14 : 0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(border, lineWidth: isEpic ? 1.5 : 1)
        }
        .shadow(color: isEpic ? color.opacity(0.45) : .clear, radius: 8)
    }

    private var border: AnyShapeStyle {
        if isEpic {
            AnyShapeStyle(LinearGradient(colors: [.purple, .indigo],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            AnyShapeStyle(color.opacity(rarity == nil ? 0.3 : 0.7))
        }
    }
}
