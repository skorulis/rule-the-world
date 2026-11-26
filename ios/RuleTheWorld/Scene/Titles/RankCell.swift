import SwiftUI

struct RankCell: View {
    let rank: RankDefinition
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = rank.icon {
                RankIcon(name: icon, rarity: rank.rarity, size: 64)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(rank.name).font(.title3.bold())
                Text(rank.description).font(.subheadline).foregroundStyle(.secondary)
                requirements
            }
            .font(.footnote)
            Spacer(minLength: 0)
        }
        .parchmentCell(
            accent: isCurrent ? .accentColor : rank.rarity.color,
            prominent: isCurrent || rank.rarity >= .epic
        )
    }

    @ViewBuilder
    private var requirements: some View {
        HStack(spacing: 10) {
            if let visited = rank.minVisits, visited > 0 {
                minimum(HexNumber(visited, color: .hexVisited, size: .small))
            }
            if let owned = rank.minOwnership, owned > 0 {
                minimum(HexNumber(owned, color: .hexOwned, size: .small))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(requirementsAccessibilityLabel)

        if rank.minOwnership == nil || rank.minVisits == nil {
            Text("Some requirements are unavailable.")
                .foregroundStyle(.secondary)
        }
        if let quantity = rank.maxQuantity {
            Text("Maximum title holders: \(quantity.formatted())")
        } else if let percentage = rank.maxPercentage {
            Text("Title holders limited to \(percentage.formatted())% of regional visitors (minimum 1 holder).")
        }
    }

    private func minimum(_ badge: some View) -> some View {
        HStack(spacing: 2) {
            badge
            Text("+").font(.system(.headline, design: .rounded, weight: .heavy))
        }
    }

    private var requirementsAccessibilityLabel: String {
        var parts: [String] = []
        if let visited = rank.minVisits, visited > 0 {
            parts.append("visit at least \(visited.formatted()) hexes")
        }
        if let owned = rank.minOwnership, owned > 0 {
            parts.append("own at least \(owned.formatted()) hexes")
        }
        return "Requires \(parts.joined(separator: ", "))"
    }
}
