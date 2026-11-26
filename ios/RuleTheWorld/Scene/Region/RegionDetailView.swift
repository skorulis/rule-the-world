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
                    RegionLeaderCell(
                        leader: leader,
                        definition: model.rankDefinition(for: leader),
                        rankName: model.rankName(for: leader)
                    )
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
