import SwiftUI

struct PowerUpInventoryView: View {
    @State var model: PowerUpInventoryViewModel

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                if !model.canUse {
                    Text("Zoom in until hexes appear to use power-ups.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let message = model.message {
                    Text(message).font(.footnote).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(model.items) { item in
                    PowerUpCard(item: item, isConsuming: model.isConsuming, canUse: model.canUse) {
                        Task { await model.consume(item: item) }
                    }
                }
            }
            .padding()
        }
        .overlay {
            if model.items.isEmpty {
                ContentUnavailableView(
                    "No power-ups",
                    systemImage: "sparkles",
                    description: Text("Power-ups you collect will appear here.")
                )
            }
        }
        .navigationTitle("Power-ups")
        .task { await model.load() }
    }
}
