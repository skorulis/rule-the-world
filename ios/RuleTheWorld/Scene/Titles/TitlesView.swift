import SwiftUI

struct TitlesView: View {
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
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(.headline)
                    Text(item.regionName).font(.subheadline)
                    if let detail = item.detail {
                        Text(detail).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
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
