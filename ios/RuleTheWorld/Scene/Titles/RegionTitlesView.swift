import SwiftUI

struct RegionTitlesView: View {
    let item: TitlesViewModel.Item

    var body: some View {
        List {
            if item.visited != nil || item.owned != nil {
                Section("Your progress") {
                    if let visited = item.visited {
                        LabeledContent("Hexes visited", value: visited.formatted())
                    }
                    if let owned = item.owned {
                        LabeledContent("Hexes owned", value: owned.formatted())
                    }
                }
            }
            Section {
                ForEach(item.ranks, id: \.number) { rank in
                    rankRow(rank)
                        .listRowBackground(rank.number == item.number ? Color.accentColor.opacity(0.12) : nil)
                }
                if !item.ranks.contains(where: { $0.number == item.number }) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name).font(.headline)
                        currentTitleLabel
                        Text("Requirements unavailable.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.accentColor.opacity(0.12))
                }
            } header: {
                Text("Titles · highest to lowest")
            } footer: {
                Text("Limited titles depend on competition. Meeting the minimum requirements does not guarantee a title.")
            }
        }
        .navigationTitle(item.regionName)
    }

    private var currentTitleLabel: some View {
        Label("Your current title", systemImage: "checkmark.circle.fill")
            .font(.subheadline).foregroundStyle(Color.accentColor)
    }

    private func rankRow(_ rank: RankDefinition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = rank.icon {
                RankIcon(name: icon, rarity: rank.rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(rank.name).font(.headline)
                if rank.number == item.number {
                    currentTitleLabel
                }
                Text(rank.description).font(.subheadline).foregroundStyle(.secondary)
                if let owned = rank.minOwnership {
                    Text("Minimum hexes owned: \(owned.formatted())")
                }
                if let visited = rank.minVisits {
                    Text("Minimum hexes visited: \(visited.formatted())")
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
        }
        .padding(.vertical, 4)
    }
}
