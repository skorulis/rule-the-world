import SwiftUI

struct RankCell: View {
    let rank: RankDefinition
    let isCurrent: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = rank.icon {
                RankIcon(name: icon, rarity: rank.rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(rank.name).font(.title3.bold())
                Text(rank.description).font(.subheadline).foregroundStyle(.secondary)
                if let owned = rank.minOwnership, owned > 0 {
                    IconText(icon: "HexOwned", text: ("Own: \(owned.formatted())+"))
                }
                if let visited = rank.minVisits, visited > 0 {
                    IconText(icon: "HexVisited", text: ("Visit: \(visited.formatted())+"))
                }
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
            .font(.footnote)
            Spacer(minLength: 0)
        }
        .gameCard(
            accent: isCurrent ? .accentColor : rank.rarity.color,
            prominent: isCurrent || rank.rarity >= .epic
        )
    }
}
