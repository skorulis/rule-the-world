import SwiftUI

struct SmallCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        let ink = Color(red: 0.18, green: 0.1, blue: 0.06)

        ZStack {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.8, green: 0.77, blue: 0.7),
                            Color(red: 0.46, green: 0.43, blue: 0.42),
                            Color(red: 0.64, green: 0.6, blue: 0.55)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Circle()
                    .strokeBorder(ink, lineWidth: 2)
                    .frame(width: 56, height: 56)
                Circle()
                    .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 50, height: 50)
                Circle()
                    .fill(LinearGradient(
                        colors: ParchmentPalette.colors,
                        startPoint: pressed ? .bottom : .top,
                        endPoint: pressed ? .top : .bottom
                    ))
                    .frame(width: 42, height: 42)
                Circle()
                    .strokeBorder(ink, lineWidth: 2)
                    .frame(width: 42, height: 42)
            }
            .compositingGroup()
            .shadow(color: ink.opacity(0.6), radius: pressed ? 1 : 2, y: pressed ? 1 : 3)
            .accessibilityHidden(true)

            configuration.label
                .font(.system(size: 24, weight: .heavy, design: .rounded))
                .foregroundStyle(ink)
        }
        .frame(width: 56, height: 56)
        .contentShape(Circle())
        .offset(y: pressed ? 2 : 0)
        .compositingGroup()
        .saturation(isEnabled ? 1 : 0.2)
        .opacity(isEnabled ? 1 : 0.45)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
    }
}

#Preview {
    HStack(spacing: 24) {
        Button("Back", systemImage: "chevron.backward") {}
        Button("Back", systemImage: "chevron.backward") {}
            .disabled(true)
    }
    .labelStyle(.iconOnly)
    .buttonStyle(SmallCircleButtonStyle())
    .padding(32)
    .background(LinearGradient(colors: [.indigo, .blue, .cyan], startPoint: .top, endPoint: .bottom))
}
