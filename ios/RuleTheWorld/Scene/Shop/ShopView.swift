import SwiftUI

struct ShopView: View {
    @State var model: ShopViewModel

    var body: some View {
        StandardListLayout("Shop") {
            Section {
                LabeledContent("Coins", value: (model.coins ?? 0).formatted())
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                ForEach(model.boxes) { box in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(box.name)
                            .font(.headline)
                            .foregroundStyle(box.rarity.color)
                        Text("Contains a random \(box.rarity.displayName.lowercased()) power-up")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            buyButton(box: box, count: 1)
                            buyButton(box: box, count: 5)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .task { await model.load() }
        .alert(
            "Loot box opened",
            isPresented: Binding(
                get: { model.openedBox != nil },
                set: { if !$0 { model.openedBox = nil } }
            ),
            presenting: model.openedBox
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { box in
            Text(box.summary)
        }
    }

    private func buyButton(box: LootBoxDefinition, count: Int) -> some View {
        Button {
            Task { await model.purchase(box: box, count: count) }
        } label: {
            Text("Buy \(count) · \((box.cost * count).formatted())")
        }
        .buttonStyle(.bordered)
        .disabled(model.isPurchasing || !model.canAfford(box, count: count))
    }
}
