import SwiftUI

struct GoldButtonStyle: ButtonStyle {
    enum Size {
        case regular
        case compact
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var size: Size = .regular
    var fillsWidth = false

    func makeBody(configuration: Configuration) -> some View {
        let pressed = isEnabled && configuration.isPressed
        let palette: GoldButtonPalette = configuration.role == .destructive ? .destructive : .gold
        let outline = palette.outline

        configuration.label
            .font(.system(size == .compact ? .headline : .title3, design: .serif, weight: .heavy))
            .foregroundStyle(palette.label)
            .tint(palette.label)
            .multilineTextAlignment(.center)
            .padding(.horizontal, size == .compact ? 14 : 24)
            .padding(.vertical, size == .compact ? 8 : 12)
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: size == .compact ? 40 : 48)
            .background {
                GoldButtonFace(pressed: pressed, palette: palette)
            }
            .offset(y: pressed ? 4 : 0)
            .background {
                RoundedRectangle(cornerRadius: 13)
                    .fill(palette.base)
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

private struct GoldButtonPalette {
    let outline: Color
    let label: Color
    let base: Color
    let face: [Color]
    let pressedFace: [Color]
    let rim: [Color]

    static let gold = GoldButtonPalette(
        outline: Color(red: 0.25, green: 0.12, blue: 0.04),
        label: Color(red: 0.25, green: 0.12, blue: 0.04),
        base: Color(red: 0.55, green: 0.25, blue: 0.05),
        face: [
            Color(red: 1, green: 0.93, blue: 0.43),
            Color(red: 1, green: 0.76, blue: 0.09),
            Color(red: 0.94, green: 0.5, blue: 0.03)
        ],
        pressedFace: [
            Color(red: 0.88, green: 0.48, blue: 0.04),
            Color(red: 1, green: 0.74, blue: 0.12)
        ],
        rim: [.yellow.opacity(0.95), Color(red: 0.69, green: 0.32, blue: 0.02)]
    )

    static let destructive = GoldButtonPalette(
        outline: Color(red: 0.3, green: 0.04, blue: 0.03),
        label: Color(red: 1, green: 0.96, blue: 0.85),
        base: Color(red: 0.42, green: 0.05, blue: 0.03),
        face: [
            Color(red: 0.93, green: 0.3, blue: 0.24),
            Color(red: 0.78, green: 0.12, blue: 0.09),
            Color(red: 0.56, green: 0.05, blue: 0.04)
        ],
        pressedFace: [
            Color(red: 0.55, green: 0.05, blue: 0.04),
            Color(red: 0.8, green: 0.16, blue: 0.12)
        ],
        rim: [Color(red: 1, green: 0.55, blue: 0.43), Color(red: 0.46, green: 0.04, blue: 0.03)]
    )
}

private struct GoldButtonFace: View {
    let pressed: Bool
    let palette: GoldButtonPalette

    private var outline: Color { palette.outline }

    var body: some View {
        RoundedRectangle(cornerRadius: 13)
            .fill(LinearGradient(
                colors: pressed ? palette.pressedFace : palette.face,
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
                            colors: palette.rim,
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
                        (CGPoint(x: 0.85, y: 0.1), 5), (CGPoint(x: 0.92, y: 0.85), 3)
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
            Button("Log out", role: .destructive) { }
            Button("Disabled destructive action", role: .destructive) { }
                .disabled(true)
            Button("Buy 1 · 10") { }
                .buttonStyle(GoldButtonStyle(size: .compact, fillsWidth: true))
        }
        .buttonStyle(GoldButtonStyle(fillsWidth: true))
    }
    .padding(24)
}
