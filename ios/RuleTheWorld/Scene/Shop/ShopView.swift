import Knit
import SwiftUI

struct ShopView: View {
    @State var model: ShopViewModel

    var body: some View {
        StandardListLayout("Shop") {
            coins
            if let errorMessage = model.errorMessage {
                Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
            }
            boxes
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

    private var coins: some View {
        ScrollBanner {
            HStack(spacing: 10) {
                Image("Coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text("Coins")
                Spacer()
                Text((model.coins ?? 0).formatted())
                    .monospacedDigit()
            }
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(Color(red: 0.25, green: 0.12, blue: 0.04))
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var boxes: some View {
        ForEach(model.boxes) { box in
            HStack(alignment: .center, spacing: 12) {
                Color.clear
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(box.name)
                        .font(.system(.title3, design: .rounded, weight: .heavy))
                        .foregroundStyle(box.rarity.color)
                    Text("Contains a random \(box.rarity.displayName.lowercased()) power-up")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        buyButton(box: box, count: 1)
                        buyButton(box: box, count: 5)
                    }
                }
            }
            .parchmentCell(rarity: box.rarity)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
        }
    }

    private func buyButton(box: LootBoxDefinition, count: Int) -> some View {
        Button {
            Task { await model.purchase(box: box, count: count) }
        } label: {
            HStack(spacing: 4) {
                Text("Buy \(count) · \((box.cost * count).formatted())")
                Image("Coin")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
                    .accessibilityHidden(true)
            }
        }
        .buttonStyle(GoldButtonStyle(size: .compact, fillsWidth: true))
        .disabled(model.isPurchasing || !model.canAfford(box, count: count))
    }
}

#Preview {
    let assembler = RuleTheWorldAssembly.testing()
    ShopView(model: assembler.resolver.shopViewModel())
}
