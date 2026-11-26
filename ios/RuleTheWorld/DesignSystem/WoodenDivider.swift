import SwiftUI

struct WoodenDivider: View {
    private let ink = Color(red: 0.16, green: 0.08, blue: 0.05)

    var body: some View {
        Rectangle()
            .fill(LinearGradient(
                colors: [
                    Color(red: 0.68, green: 0.4, blue: 0.2),
                    Color(red: 0.4, green: 0.2, blue: 0.1),
                    Color(red: 0.26, green: 0.12, blue: 0.07)
                ],
                startPoint: .top,
                endPoint: .bottom
            ))
            .overlay {
                Canvas { context, size in
                    for index in 0..<4 {
                        let start = CGFloat(index) * size.width / 4
                        var grain = Path()
                        grain.move(to: CGPoint(x: start, y: 5 + CGFloat(index % 2) * 3))
                        grain.addQuadCurve(
                            to: CGPoint(x: start + size.width * 0.3, y: 7),
                            control: CGPoint(x: start + size.width * 0.15, y: 3)
                        )
                        context.stroke(grain, with: .color(ink.opacity(0.5)), lineWidth: 1)
                    }
                }
            }
            .overlay(alignment: .top) {
                Rectangle().fill(ink).frame(height: 2)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(red: 0.9, green: 0.65, blue: 0.35))
                    .frame(height: 1)
                    .padding(.top, 2)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(ink).frame(height: 3)
            }
            .frame(height: 14)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

#Preview {
    VStack(spacing: 0) {
        Color.blue
        WoodenDivider()
        Color(red: 0.2, green: 0.12, blue: 0.13)
            .overlay {
                ParchmentPanel {
                    Text("Your next adventure")
                }
                .padding()
            }
    }
}
