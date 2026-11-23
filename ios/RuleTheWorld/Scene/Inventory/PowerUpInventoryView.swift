import SwiftUI

struct PowerUpInventoryView: View {
    @State var model: PowerUpInventoryViewModel

    var body: some View {
        List {
            if let message = model.message {
                Section {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                }
            }
            if model.items.isEmpty {
                ContentUnavailableView(
                    "No power-ups",
                    systemImage: "sparkles",
                    description: Text("Power-ups you collect will appear here.")
                )
            } else {
                ForEach(model.items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(item.name).font(.headline)
                            Spacer()
                            Text("x\(item.count)").foregroundStyle(.secondary)
                            Button("Use") {
                                Task { await model.consume(item: item) }
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isConsuming || item.count < 1)
                        }
                        if let rarity = item.rarity {
                            Text(rarity.displayName).font(.caption).foregroundStyle(.secondary)
                        }
                        if let detail = item.detail {
                            Text(detail).font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Power-ups")
        .task { await model.load() }
    }
}
