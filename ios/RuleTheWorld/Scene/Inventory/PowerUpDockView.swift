import SwiftUI

struct PowerUpDockView: View {
    @Bindable var model: PowerUpInventoryViewModel
    let onInfo: () -> Void
    let onClose: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? nil : model.activationID)
                    .accessibilityHidden(true)
                Text(model.selectedItem?.name ?? "Power-ups")
                    .font(.headline)
                Spacer(minLength: 4)
                Button(action: onInfo) {
                    Image(systemName: "info.circle").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Power-up descriptions")
                .disabled(model.isConsuming)
                Button(action: onClose) {
                    Image(systemName: "chevron.down").frame(width: 44, height: 44)
                }
                .accessibilityLabel("Close power-ups")
            }
            if !model.canUse {
                Text("Zoom in until hexes appear to use power-ups.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let message = model.message {
                Text(message)
                    .font(.footnote)
                    .accessibilityAddTraits(.updatesFrequently)
            }
            if model.items.isEmpty {
                Text("No power-ups. Power-ups you collect will appear here.")
                    .font(.footnote).foregroundStyle(.secondary)
            } else {
                if model.selectedItem != nil {
                    HStack {
                        if model.isConsuming { ProgressView().accessibilityLabel("Using power-up") }
                        Spacer()
                        Button("Use") {
                            Task { await model.consumeSelected() }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .accessibilityLabel("Use \(model.selectedItem?.name ?? "power-up")")
                        .disabled(model.isConsuming || !model.canUse)
                    }
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 12) {
                        ForEach(model.items) { item in
                            Button {
                                model.selectedItemID = item.id
                            } label: {
                                PowerUpIcon(type: item.definition.type, rarity: item.rarity, size: 48)
                                    .phaseAnimator(
                                        [false, true, false], trigger: model.activationID
                                    ) { icon, expanded in
                                        icon.scaleEffect(
                                            !reduceMotion && expanded && model.activatedItemID == item.id ? 1.12 : 1
                                        )
                                    }
                                    .padding(6)
                                    .background(
                                        model.selectedItemID == item.id ? Color.accentColor.opacity(0.25) : .clear,
                                        in: .rect(cornerRadius: 14)
                                    )
                                    .overlay(alignment: .bottomTrailing) {
                                        Text("×\(item.count)")
                                            .font(.caption2.monospacedDigit().bold())
                                            .padding(3)
                                            .background(.regularMaterial, in: .capsule)
                                    }
                            }
                            .buttonStyle(.plain)
                            .disabled(model.isConsuming)
                            .accessibilityLabel("\(item.name), \(item.count) available")
                            .accessibilityAddTraits(model.selectedItemID == item.id ? .isSelected : [])
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(12)
        .background(.regularMaterial, in: .rect(cornerRadius: 20))
    }
}
