import SwiftUI

struct GoldButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        let outline = Color(red: 0.25, green: 0.12, blue: 0.04)

        configuration.label
            .font(.system(.title3, design: .serif, weight: .heavy))
            .foregroundStyle(outline)
            .tint(outline)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 48)
            .background {
                GoldButtonFace(pressed: pressed)
            }
            .offset(y: pressed ? 4 : 0)
            .background {
                RoundedRectangle(cornerRadius: 13)
                    .fill(Color(red: 0.55, green: 0.25, blue: 0.05))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(outline, lineWidth: 2)
                    }
                    .offset(y: 6)
            }
            .padding(.bottom, 6)
            .contentShape(RoundedRectangle(cornerRadius: 13))
            .shadow(color: .black.opacity(isEnabled ? 0.25 : 0.1), radius: pressed ? 1 : 3, y: pressed ? 1 : 3)
            .saturation(isEnabled ? 1 : 0.15)
            .opacity(isEnabled ? 1 : 0.55)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.1), value: pressed)
    }
}

private struct GoldButtonFace: View {
    let pressed: Bool
    private let outline = Color(red: 0.25, green: 0.12, blue: 0.04)

    var body: some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(LinearGradient(
                colors: pressed ? [
                    Color(red: 0.88, green: 0.48, blue: 0.04),
                    Color(red: 1, green: 0.74, blue: 0.12),
                ] : [
                    Color(red: 1, green: 0.93, blue: 0.43),
                    Color(red: 1, green: 0.76, blue: 0.09),
                    Color(red: 0.94, green: 0.5, blue: 0.03),
                ],
                startPoint: .top, endPoint: .bottom
            ))
            .overlay {
                RoundedRectangle(cornerRadius: 13)
                    .strokeBorder(outline, lineWidth: 2)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .inset(by: 4)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.yellow.opacity(0.95), Color(red: 0.69, green: 0.32, blue: 0.02)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 2
                    )
            }
            .overlay {
                GeometryReader { geometry in
                    RoundedRectangle(cornerRadius: 8)
                        .fill(LinearGradient(
                            colors: [.white.opacity(pressed ? 0.12 : 0.5), .white.opacity(0)],
                            startPoint: .top, endPoint: .bottom
                        ))
                        .frame(height: max(0, geometry.size.height * 0.48))
                        .padding(6)
                }
            }
            .overlay {
                Canvas { context, size in
                    let marks: [(CGPoint, CGFloat)] = [
                        (CGPoint(x: 0.09, y: 0.11), 5), (CGPoint(x: 0.15, y: 0.9), 7),
                        (CGPoint(x: 0.33, y: 0.08), 4), (CGPoint(x: 0.72, y: 0.91), 6),
                        (CGPoint(x: 0.85, y: 0.1), 5), (CGPoint(x: 0.92, y: 0.85), 3),
                    ]
                    for (position, length) in marks {
                        let point = CGPoint(x: size.width * position.x, y: size.height * position.y)
                        var mark = Path()
                        mark.move(to: point)
                        mark.addLine(to: CGPoint(x: point.x + length, y: point.y - 1))
                        context.stroke(
                            mark, with: .color(outline.opacity(0.4)),
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                        )
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 13))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    ParchmentPanel {
        VStack(spacing: 24) {
            Button("Sign in") { }
            Button("Sign up") { }
                .disabled(true)
            Button { } label: {
                ProgressView()
            }
            Button("A longer button title that can wrap onto multiple lines") { }
        }
        .buttonStyle(GoldButtonStyle(fillsWidth: true))
    }
    .padding(24)
}
