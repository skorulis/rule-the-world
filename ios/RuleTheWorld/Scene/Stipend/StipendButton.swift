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

    @ViewBuilder
    private func button(at date: Date) -> some View {
        if model.isCollecting {
            Label("Collecting…", systemImage: "dollarsign.circle")
                .foregroundStyle(.secondary)
        } else if model.isAvailable(at: date) {
            Button {
                collect()
            } label: {
                Label(
                    model.amount.map { "Collect \($0.formatted()) daily stipend" } ?? "Collect daily stipend",
                    systemImage: "dollarsign.circle.fill"
                )
            }
        } else if let remaining = model.remaining(at: date) {
            LabeledContent {
                Text(remaining.formatted(.time(pattern: .hourMinuteSecond)))
                    .monospacedDigit()
            } label: {
                Label("Next stipend in", systemImage: "dollarsign.circle")
            }
            .foregroundStyle(.secondary)
        } else {
            Label("Stipend unavailable", systemImage: "dollarsign.circle")
                .foregroundStyle(.secondary)
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
