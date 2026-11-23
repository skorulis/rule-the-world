import SwiftUI

struct DailyRewardButton: View {
    @Bindable var model: DailyRewardViewModel
    var onClaimed: (AddPowerUpResponse) -> Void = { _ in }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 4) {
                button(at: context.date)
                if let errorMessage = model.errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .alert(
            "Common Daily Box",
            isPresented: Binding(get: { model.reward != nil }, set: { if !$0 { model.reward = nil } }),
            presenting: model.reward
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { reward in
            Text("You got \(reward.displayName)\n\(reward.formattedDescription)")
        }
    }

    @ViewBuilder
    private func button(at date: Date) -> some View {
        if model.isClaiming {
            Label("Opening…", systemImage: "gift")
                .foregroundStyle(.secondary)
        } else if model.isAvailable(at: date) {
            Button {
                Task {
                    if let response = await model.claim() {
                        onClaimed(response)
                    }
                }
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
}
