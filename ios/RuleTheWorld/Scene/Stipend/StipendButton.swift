import SwiftUI

struct StipendButton: View {
    @Bindable var model: StipendViewModel
    var onCollected: (StipendResponse) -> Void = { _ in }
    @State private var reveal: RewardRevealPhase?

    /// Minimum time the "opening" animation plays so it reads as a reveal
    /// even when the server responds instantly.
    private static let minimumOpening: Duration = .seconds(0.9)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let isEnabled = model.isAvailable(at: context.date) && !model.isCollecting
            RewardActionRow(
                systemName: isEnabled ? "dollarsign.circle.fill" : "dollarsign.circle",
                text: buttonText(at: context.date),
                isEnabled: isEnabled,
                errorMessage: model.errorMessage,
                action: collect
            )
        }
        .fullScreenCover(
            isPresented: Binding(get: { reveal != nil }, set: { if !$0 { reveal = nil } })
        ) {
            RewardRevealView(
                phase: reveal ?? .opening,
                accent: .yellow,
                boxSymbol: "dollarsign.circle.fill",
                onDone: {
                    reveal = nil
                    model.collected = nil
                },
                card: {
                    if let collected = model.collected {
                        rewardCard(collected)
                    }
                }
            )
        }
    }

    private func buttonText(at date: Date) -> String {
        if model.isCollecting {
            return "Collecting…"
        } else if model.isAvailable(at: date) {
            return model.amount.map { "Collect \($0.formatted()) stipend" } ?? "Collect stipend"
        } else if let remaining = model.remaining(at: date) {
            return "Next stipend in \(remaining.formatted(.time(pattern: .hourMinuteSecond)))"
        } else {
            return "Stipend unavailable"
        }
    }

    private func collect() {
        reveal = .opening
        Task {
            let started = Date.now
            guard let response = await model.collect() else {
                reveal = nil
                return
            }
            onCollected(response)
            let remaining = Self.minimumOpening - .seconds(started.distance(to: .now))
            if remaining > .zero {
                try? await Task.sleep(for: remaining)
            }
            withAnimation { reveal = .revealed }
        }
    }

    private func rewardCard(_ coins: Int) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 96))
                .foregroundStyle(.yellow.gradient)
                .shadow(color: .yellow.opacity(0.5), radius: 8)
            Text("+\(coins.formatted()) coins")
                .font(.title2.bold())
            Text("Daily stipend collected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
