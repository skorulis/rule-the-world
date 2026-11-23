import SwiftUI

struct StipendButton: View {
    @Bindable var model: StipendViewModel
    var onCollected: (StipendResponse) -> Void = { _ in }

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
            "Daily Stipend",
            isPresented: Binding(get: { model.collected != nil }, set: { if !$0 { model.collected = nil } }),
            presenting: model.collected
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { stipend in
            Text("You collected \(stipend.formatted()) coins")
        }
    }

    @ViewBuilder
    private func button(at date: Date) -> some View {
        if model.isCollecting {
            Label("Collecting…", systemImage: "dollarsign.circle")
                .foregroundStyle(.secondary)
        } else if model.isAvailable(at: date) {
            Button {
                Task {
                    if let response = await model.collect() {
                        onCollected(response)
                    }
                }
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
}
