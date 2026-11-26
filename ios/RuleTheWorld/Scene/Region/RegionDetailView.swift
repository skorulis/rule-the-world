import SwiftUI

struct RegionDetailView: View {
    let model: RegionDetailViewModel

    var body: some View {
        Group {
            if model.isLoading {
                ProgressView()
            } else if let message = model.message {
                ContentUnavailableView {
                    Label("Couldn't load leaders", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try again") {
                        Task { await model.load() }
                    }
                }
            } else if let leaders = model.leaders, !leaders.isEmpty {
                List(Array(leaders.enumerated()), id: \.offset) { _, leader in
                    leaderRow(leader)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } else {
                ContentUnavailableView(
                    "No ranked users",
                    systemImage: "crown",
                    description: Text("Nobody holds a top rank in \(model.region.name) yet.")
                )
            }
        }
        .navigationTitle(model.region.name)
        .task { await model.load() }
    }

    private func leaderRow(_ leader: RegionLeader) -> some View {
        let definition = model.rankDefinition(for: leader)
        return HStack(alignment: .top, spacing: 12) {
            if let icon = definition?.icon {
                RankIcon(name: icon, rarity: definition?.rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(leader.name).font(.headline)
                Text(model.rankName(for: leader))
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Label {
                Text(leader.owned.formatted())
            } icon: {
                Image("HexOwned").resizable().frame(width: 14, height: 14)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .gameCard(rarity: definition?.rarity)
    }
}

#Preview {
    NavigationStack {
        RegionDetailView(
            model: RegionDetailViewModel(
                region: MapRegionBoundary(id: "1", name: "Australia", kind: .country, polygons: [])
            )
        )
    }
}
