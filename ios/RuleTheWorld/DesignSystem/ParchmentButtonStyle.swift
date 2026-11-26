import SwiftUI

struct ParchmentButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed

        configuration.label
            .font(.system(.callout, design: .serif, weight: .bold))
            .foregroundStyle(Color(red: 0.3, green: 0.15, blue: 0.08))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .opacity(isEnabled ? (pressed ? 0.65 : 1) : 0.4)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
    }
}

#Preview {
    ParchmentPanel {
        VStack(spacing: 12) {
            Button("Need an account? Sign up") { }
            Button("Already have an account? Sign in") { }
            Button("Disabled action") { }
                .disabled(true)
        }
        .buttonStyle(ParchmentButtonStyle())
    }
    .padding(24)
}
