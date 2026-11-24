import SwiftUI

struct RegionTitlesView: View {
    let item: TitlesViewModel.Item

    var body: some View {
        ScrollViewReader { proxy in
            List {
                if item.visited != nil || item.owned != nil {
                    Section("Your progress") {
                        if let visited = item.visited {
                            LabeledContent {
                                Text(visited.formatted())
                            } label: {
                                Label {
                                    Text("Hexes visited")
                                } icon: {
                                    Image("HexVisited").resizable().frame(width: 18, height: 18)
                                }
                            }
                        }
                        if let owned = item.owned {
                            LabeledContent {
                                Text(owned.formatted())
                            } label: {
                                Label {
                                    Text("Hexes owned")
                                } icon: {
                                    Image("HexOwned").resizable().frame(width: 18, height: 18)
                                }
                            }
                        }
                    }
                }
                Section {
                    ForEach(item.ranks, id: \.number) { rank in
                        rankRow(rank)
                            .id(rank.number)
                            .listRowBackground(rank.number == item.number ? Color.accentColor.opacity(0.12) : nil)
                    }
                    if !item.ranks.contains(where: { $0.number == item.number }) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name).font(.headline)
                            Text("Requirements unavailable.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        .id(item.number)
                        .listRowBackground(Color.accentColor.opacity(0.12))
                    }
                } header: {
                    Text("Titles · highest to lowest")
                } footer: {
                    Text("Limited titles depend on competition. Meeting the minimum requirements does not guarantee a title.")
                }
            }
            .onAppear {
                proxy.scrollTo(item.number, anchor: .center)
            }
        }
        .navigationTitle(item.regionName)
    }

    private func rankRow(_ rank: RankDefinition) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = rank.icon {
                RankIcon(name: icon, rarity: rank.rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(rank.name).font(.headline)
                Text(rank.description).font(.subheadline).foregroundStyle(.secondary)
                if let owned = rank.minOwnership {
                    Label {
                        Text("Minimum hexes owned: \(owned.formatted())")
                    } icon: {
                        Image("HexOwned").resizable().frame(width: 14, height: 14)
                    }
                }
                if let visited = rank.minVisits {
                    Label {
                        Text("Minimum hexes visited: \(visited.formatted())")
                    } icon: {
                        Image("HexVisited").resizable().frame(width: 14, height: 14)
                    }
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
