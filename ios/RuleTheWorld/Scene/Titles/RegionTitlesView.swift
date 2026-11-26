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
                                    Image("HexVisited").resizable().scaledToFit().frame(width: 32, height: 32)
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
                                    Image("HexOwned").resizable().scaledToFit().frame(width: 32, height: 32)
                                }
                            }
                        }
                    }
                    .font(.system(.title3, design: .rounded, weight: .semibold))
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
}
