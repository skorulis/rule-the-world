import SwiftUI

struct DailyRewardButton: View {
    @Bindable var model: DailyRewardViewModel
    var onClaimed: (AddPowerUpResponse) -> Void = { _ in }
    @State private var reveal: RewardRevealPhase?

    /// Minimum time the "opening" animation plays so it reads as a reveal
    /// even when the server responds instantly.
    private static let minimumOpening: Duration = .seconds(0.9)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                button(at: context.date)
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .fullScreenCover(
            isPresented: Binding(get: { reveal != nil }, set: { if !$0 { reveal = nil } })
        ) {
            RewardRevealView(
                phase: reveal ?? .opening,
                accent: model.reward?.rarity.color ?? .gray,
                boxSymbol: "gift.fill",
                onDone: {
                    reveal = nil
                    model.reward = nil
                },
                card: {
                    if let reward = model.reward {
                        rewardCard(reward)
                    }
                }
            )
        }
    }

    @ViewBuilder
    private func button(at date: Date) -> some View {
        if model.isClaiming {
            Label("Opening…", systemImage: "gift")
                .foregroundStyle(.secondary)
        } else if model.isAvailable(at: date) {
            Button {
                open()
            } label: {
                Label("Open Common Daily Box", systemImage: "gift.fill")
            }
        } else if let remaining = model.remaining(at: date) {
            LabeledContent {
                Text(remaining.formatted(.time(pattern: .hourMinuteSecond)))
                    .monospacedDigit()
            } label: {
                Label("Next box in", systemImage: "gift")
            }
            .foregroundStyle(.secondary)
        } else {
            Label("Daily box unavailable", systemImage: "gift")
                .foregroundStyle(.secondary)
        }
    }

    private func open() {
        reveal = .opening
        Task {
            let started = Date.now
            guard let response = await model.claim() else {
                reveal = nil
                return
            }
            onClaimed(response)
            let remaining = Self.minimumOpening - .seconds(started.distance(to: .now))
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            }
            withAnimation { reveal = .revealed }
        }
    }

    private func rewardCard(_ reward: PowerUpDefinition) -> some View {
        VStack(spacing: 14) {
            PowerUpIcon(type: reward.type, rarity: reward.rarity, size: 96)
            Text(reward.displayName)
                .font(.title2.bold())
                .foregroundStyle(reward.rarity.color)
            Text(reward.formattedDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
