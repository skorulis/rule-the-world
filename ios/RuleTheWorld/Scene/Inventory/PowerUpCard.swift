import SwiftUI

/// A "loot card" cell for a power-up: rarity is conveyed by the card's
/// border, tint and glow instead of a text label.
struct PowerUpCard: View {
    let item: PowerUpInventoryViewModel.Item

    private var rarity: Rarity { item.rarity }
    private var color: Color { rarity.color }
    private var isHighRarity: Bool { rarity >= .epic }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            PowerUpIcon(type: item.definition.type, rarity: rarity)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.name).font(.headline)
                    Spacer()
                    Text("×\(item.count)")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(color)
                }
                Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(isHighRarity ? 0.14 : 0.07))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(border, lineWidth: isHighRarity ? 1.5 : 1)
        }
        .shadow(color: isHighRarity ? color.opacity(0.45) : .clear, radius: 8)
    }

    private var border: AnyShapeStyle {
        if isHighRarity {
            AnyShapeStyle(LinearGradient(colors: [color, rarity == .legendary ? .yellow : .indigo],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
        } else {
            AnyShapeStyle(color.opacity(0.7))
        }
    }
}
