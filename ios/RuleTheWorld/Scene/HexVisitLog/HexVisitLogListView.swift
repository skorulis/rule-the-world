import SwiftUI

struct HexVisitLogListView: View {
    @State var model: HexVisitLogListViewModel

    var body: some View {
        List {
            if let errorMessage = model.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                }
            }
            ForEach(model.entries, id: \.id) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .standard))
                        .font(.headline)
                    Text("Hex \(entry.cell.description)")
                        .font(.caption)
                        .monospaced()
                    Text(detailLine(entry))
                        .font(.caption)
                        .monospaced()
                }
            }
        }
        .navigationTitle("Visit Log")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await model.sync() }
                } label: {
                    HStack {
                        if model.isSyncing {
                            ProgressView()
                        }
                        Text("Sync (\(model.pendingCount))")
                    }
                }
                .disabled(model.isSyncing || model.pendingCount == 0)
                .accessibilityIdentifier("syncVisits")
            }
        }
        .overlay {
            if model.entries.isEmpty {
                ContentUnavailableView("No visits yet", systemImage: "hexagon")
            }
        }
        .task { await model.observeEntries() }
        .refreshable { await model.load() }
    }

    private func detailLine(_ entry: HexVisitLog) -> String {
        let speedText = entry.speed.map { String(format: "%.1f km/h", $0 * 3.6) } ?? "—"
        return String(
            format: "%.5f, %.5f  %@  %@  Score %.2f  ×%ld",
            entry.latitude,
            entry.longitude,
            speedText,
            entry.locationType.rawValue.capitalized,
            entry.score,
            entry.count
        )
    }
}
