import SwiftUI

struct PowerUpDockView: View {
    @Bindable var model: PowerUpInventoryViewModel
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let ink = Color(red: 0.25, green: 0.12, blue: 0.04)

    var body: some View {
        VStack(spacing: 8) {
            if !model.canUse && !model.items.isEmpty {
                status("Zoom in until hexes appear to use power-ups.")
            }
            if let message = model.message {
                status(message)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if model.selectedItem != nil {
                Button {
                    Task { await model.consumeSelected() }
                } label: {
                    HStack {
                        if model.isConsuming {
                            ProgressView().accessibilityLabel("Using power-up")
                        }
                        Text("Use")
                    }
                }
                .buttonStyle(GoldButtonStyle())
                .accessibilityLabel("Use \(model.selectedItem?.name ?? "power-up")")
                .disabled(model.isConsuming || !model.canUse)
            }
            ParchmentPanel(contentInsets: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 32)) {
                if model.items.isEmpty {
                    Text("No power-ups")
                        .font(.footnote)
                        .foregroundStyle(ink)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(model.items) { item in
                                iconButton(for: item)
                            }
                        }
                        .padding(4)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button("Close power-ups", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(SmallCircleButtonStyle())
                    .offset(x: 12, y: -12)
            }
            .padding([.top, .trailing], 12)
        }
    }

    private func iconButton(for item: PowerUpInventoryViewModel.Item) -> some View {
        Button {
            model.selectedItemID = item.id
        } label: {
            PowerUpIcon(type: item.definition.type, rarity: item.rarity, size: 48)
                .phaseAnimator([false, true, false], trigger: model.activationID) { icon, expanded in
                    icon.scaleEffect(!reduceMotion && expanded && model.activatedItemID == item.id ? 1.12 : 1)
                }
                .padding(6)
                .background(
                    model.selectedItemID == item.id ? ink.opacity(0.18) : .clear,
                    in: .rect(cornerRadius: 14)
                )
                .overlay(alignment: .bottomTrailing) {
                    Text("×\(item.count)")
                        .font(.caption2.monospacedDigit().bold())
                        .foregroundStyle(ink)
                        .padding(3)
                        .background(ParchmentPalette.colors[1], in: .capsule)
                }
        }
        .buttonStyle(.plain)
        .disabled(model.isConsuming)
        .accessibilityLabel("\(item.name), \(item.count) available")
        .accessibilityAddTraits(model.selectedItemID == item.id ? .isSelected : [])
    }

    private func status(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(ink)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(ParchmentPalette.colors[1], in: .rect(cornerRadius: 8))
    }
}
