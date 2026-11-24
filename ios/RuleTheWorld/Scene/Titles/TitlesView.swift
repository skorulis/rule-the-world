import ASKCoordinator
import SwiftUI

struct TitlesView: View {
    @Environment(\.coordinator) private var coordinator
    @State var model: TitlesViewModel

    var body: some View {
        List {
            if let message = model.message, !model.items.isEmpty {
                Section {
                    Text(message).foregroundStyle(.secondary)
                    Button("Retry") { Task { await model.load() } }
                        .disabled(model.isLoading)
                }
            }
            ForEach(model.items) { item in
                Button {
                    coordinator?.push(MainPath.regionTitles(item))
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        if let icon = item.icon {
                            RankIcon(name: icon, rarity: item.rarity)
                                .padding(.top, 2)
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name).font(.headline)
                            Text(item.regionName).font(.subheadline)
                            if let visited = item.visited, let owned = item.owned {
                                Text("\(visited) visited · \(owned) owned")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            if let detail = item.detail {
                                Text(detail).font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if model.items.isEmpty {
                if model.isLoading || (!model.hasLoaded && model.message == nil) {
                    ProgressView("Loading titles…")
                } else if let message = model.message {
                    ContentUnavailableView {
                        Label("Unable to load titles", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Retry") { Task { await model.load() } }
                    }
                } else {
                    ContentUnavailableView(
                        "No titles yet",
                        systemImage: "crown",
                        description: Text("Titles you are awarded will appear here.")
                    )
                }
            }
        }
        .navigationTitle("Titles")
        .task { await model.load() }
        .refreshable { await model.load() }
    }
}
