import SwiftUI

struct RewardActionRow: View {
    let systemName: String
    let text: String
    let isEnabled: Bool
    var errorMessage: String?
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 10))

        layout {
            GameSymbol(systemName)
                .frame(width: 52, height: 52)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                Button(action: action) {
                    Text(text)
                        .monospacedDigit()
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(GoldButtonStyle(fillsWidth: true))
                .disabled(!isEnabled)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 0.3, green: 0.15, blue: 0.08))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview("Reward states") {
    ScrollView {
        TitledParchmentPanel("Daily rewards") {
            VStack(spacing: 16) {
                RewardActionRow(systemName: "gift.fill", text: "Open Common Daily Box", isEnabled: true) {}
                RewardActionRow(
                    systemName: "dollarsign.circle.fill",
                    text: "Collect 72 daily stipend",
                    isEnabled: true
                ) {}
                RewardActionRow(systemName: "gift", text: "Next box in 12:34:56", isEnabled: false) {}
                RewardActionRow(systemName: "gift", text: "Opening…", isEnabled: false) {}
                RewardActionRow(systemName: "dollarsign.circle", text: "Collecting…", isEnabled: false) {}
                RewardActionRow(systemName: "gift", text: "Daily box unavailable", isEnabled: false) {}
                RewardActionRow(
                    systemName: "dollarsign.circle.fill",
                    text: "Collect daily stipend",
                    isEnabled: true,
                    errorMessage: "Couldn't collect your stipend. Try again."
                ) {}
            }
        }
        .padding(20)
    }
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}

#Preview("Large value and text") {
    ScrollView {
        TitledParchmentPanel("Daily rewards") {
            RewardActionRow(
                systemName: "dollarsign.circle.fill",
                text: "Collect 12,345,678 daily stipend",
                isEnabled: true
            ) {}
        }
        .padding(20)
    }
    .environment(\.dynamicTypeSize, .accessibility1)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}
