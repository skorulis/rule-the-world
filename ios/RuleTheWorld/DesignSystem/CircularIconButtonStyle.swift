import SwiftUI

struct CircularIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var diameter: CGFloat = 60

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        let ink = Color(red: 0.25, green: 0.12, blue: 0.04)
        configuration.label
            .font(.system(size: diameter * 0.4, weight: .bold, design: .rounded))
            .foregroundStyle(ink)
            .labelStyle(.iconOnly)
            .frame(width: diameter, height: diameter)
            .background {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color(red: 1, green: 0.95, blue: 0.6), .yellow, .orange],
                        startPoint: pressed ? .bottom : .topLeading, endPoint: pressed ? .top : .bottomTrailing
                    ))
                    .overlay { Circle().strokeBorder(ink, lineWidth: 2) }
                    .overlay { Circle().inset(by: 5).strokeBorder(.white.opacity(0.7), lineWidth: 2) }
            }
            .offset(y: pressed ? 3 : 0)
            .background { Circle().fill(ink).offset(y: 4) }
            .padding(.bottom, 4)
            .contentShape(Circle())
            .shadow(color: ink.opacity(0.35), radius: pressed ? 1 : 3, y: 3)
            .saturation(isEnabled ? 1 : 0.15)
            .opacity(isEnabled ? 1 : 0.5)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
    }
}

#Preview {
    HStack(spacing: 24) {
        Button("Shuffle", systemImage: "dice.fill") {}
        Button("Shuffle", systemImage: "dice.fill") {}.disabled(true)
    }
    .buttonStyle(CircularIconButtonStyle())
    .padding()
}
