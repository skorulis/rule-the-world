import SwiftUI

struct RegionTitlesView: View {
    let item: TitlesViewModel.Item

    var body: some View {
        StandardListLayout(item.regionName, scrollTarget: item.number) {
            if item.visited != nil || item.owned != nil {
                TitledParchmentPanel("Your progress") {
                    HStack(spacing: 16) {
                        if let visited = item.visited {
                            progressStat(visited, title: "Hexes\nVisited", color: .hexVisited)
                        }
                        if let owned = item.owned {
                            progressStat(owned, title: "Hexes\nOwned", color: .hexOwned)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            Section {
                ForEach(item.ranks, id: \.number) { rank in
                    RankCell(rank: rank, isCurrent: rank.number == item.number)
                        .id(rank.number)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                if !item.ranks.contains(where: { $0.number == item.number }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.headline)
                        Text("Requirements unavailable.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .parchmentCell(accent: .accentColor, prominent: true)
                    .id(item.number)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
            } header: {
                Text("Titles · highest to lowest")
            } footer: {
                Text("Limited titles depend on competition. "
                    + "Meeting the minimum requirements does not guarantee a title.")
            }
        }
    }

    private func progressStat(_ value: Int, title: LocalizedStringKey, color: Color) -> some View {
        HStack(spacing: 8) {
            HexNumber(value, color: color)
            Text(title)
                .font(.system(.headline, design: .rounded, weight: .heavy))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    RegionTitlesView(
        item: TitlesViewModel.Item(
            id: "suburb:1", number: 3, type: "suburb",
            ranks: [
                RankDefinition(
                    number: 1, name: "Mayor", rarity: .legendary,
                    description: "The most decorated title in the region.",
                    icon: "RankMayor", minOwnership: 50, minVisits: 60,
                    maxQuantity: 1, maxPercentage: nil, stipend: 50
                ),
                RankDefinition(
                    number: 3, name: "Councillor", rarity: .epic,
                    description: "A seat on the regional council.",
                    icon: "RankCouncillor", minOwnership: 17, minVisits: 23,
                    maxQuantity: nil, maxPercentage: 5, stipend: 9
                ),
                RankDefinition(
                    number: 6, name: "Yeoman", rarity: .common,
                    description: "A dependable local landholder.",
                    icon: "RankYeoman", minOwnership: 5, minVisits: 8,
                    maxQuantity: nil, maxPercentage: nil, stipend: 2
                )
            ],
            name: "Sydney Councillor", icon: "RankCouncillor", rarity: .epic,
            regionName: "Sydney", detail: nil, visited: 23, owned: 17, stipend: 9
        )
    )
}
