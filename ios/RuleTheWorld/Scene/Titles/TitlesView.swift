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
                            if item.visited != nil || item.stipend != nil {
                                HStack(spacing: 6) {
                                    if let visited = item.visited, let owned = item.owned {
                                        Image("HexVisited").resizable().frame(width: 20, height: 20)
                                        Text(visited.formatted())
                                        Image("HexOwned").resizable().frame(width: 20, height: 20)
                                            .padding(.leading, 6)
                                        Text(owned.formatted())
                                    }
                                    if let stipend = item.stipend {
                                        Image("Coin").resizable().frame(width: 20, height: 20)
                                            .padding(.leading, item.visited == nil ? 0 : 6)
                                        Text("+\(stipend.formatted())")
                                    }
                                }
                                .font(.subheadline.bold())
                                .foregroundStyle(.secondary)
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(accessibilityLabel(for: item))
                            }
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.footnote).foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .gameCard(rarity: item.rarity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
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

    private func accessibilityLabel(for item: TitlesViewModel.Item) -> String {
        var parts: [String] = []
        if let visited = item.visited, let owned = item.owned {
            parts.append("\(visited.formatted()) hexes visited, \(owned.formatted()) hexes owned")
        }
        if let stipend = item.stipend {
            parts.append("daily stipend of \(stipend.formatted()) coins")
        }
        return parts.joined(separator: ", ")
    }
}
