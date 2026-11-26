import SwiftUI

struct HexNumber: View {
    let value: Int
    var color: Color = .blue

    @ScaledMetric(relativeTo: .largeTitle) private var badgeWidth: CGFloat = 64

    init(_ value: Int, color: Color = .blue) {
        self.value = value
        self.color = color
    }

    var body: some View {
        let text = value.formatted()
        let width = badgeWidth * min(2, max(1, CGFloat(text.count) / 4))
        let ink = Color(red: 0.1, green: 0.12, blue: 0.16)
        let depth = width * 0.07

        ZStack {
            HexNumberShape()
                .fill(LinearGradient(colors: [color, ink], startPoint: .top, endPoint: .bottom))
                .overlay {
                    HexNumberShape()
                        .stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }
                .offset(x: width * 0.015, y: depth)
                .accessibilityHidden(true)
            badgeFace(ink: ink)
                .accessibilityHidden(true)

            LargeValueText(text, color: .white)
                .lineLimit(1)
                .minimumScaleFactor(0.25)
                .padding(.horizontal, width * 0.17)
        }
        .frame(width: width, height: width * 1.15)
        .padding(.bottom, depth)
        .compositingGroup()
        .shadow(color: ink.opacity(0.4), radius: 1, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(text))
    }

    private func badgeFace(ink: Color) -> some View {
        ZStack {
            HexNumberShape()
                .fill(LinearGradient(
                    colors: [.white, color, ink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            HexNumberShape()
                .stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
            HexNumberShape()
                .stroke(.white.opacity(0.75), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))
                .scaleEffect(0.92)
            HexNumberShape()
                .fill(LinearGradient(colors: [ink, color], startPoint: .topLeading, endPoint: .bottomTrailing))
                .scaleEffect(0.84)
            HexNumberShape()
                .fill(LinearGradient(
                    colors: [color, color, ink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay {
                    LinearGradient(colors: [.white.opacity(0.35), .clear], startPoint: .top, endPoint: .center)
                        .clipShape(HexNumberShape())
                }
                .scaleEffect(0.74)
            HexNumberShape()
                .stroke(.white.opacity(0.6), style: StrokeStyle(lineWidth: 1, lineJoin: .round))
                .scaleEffect(0.74)
        }
    }
}

private struct HexNumberShape: Shape {
    func path(in rect: CGRect) -> Path {
        let badge = rect.insetBy(dx: 2, dy: 2)
        let corners = [
            CGPoint(x: badge.midX, y: badge.minY),
            CGPoint(x: badge.maxX, y: badge.minY + badge.height * 0.25),
            CGPoint(x: badge.maxX, y: badge.minY + badge.height * 0.75),
            CGPoint(x: badge.midX, y: badge.maxY),
            CGPoint(x: badge.minX, y: badge.minY + badge.height * 0.75),
            CGPoint(x: badge.minX, y: badge.minY + badge.height * 0.25),
        ]
        let rounding: CGFloat = 0.1
        return Path { path in
            for index in corners.indices {
                let corner = corners[index]
                let previous = corners[(index + corners.count - 1) % corners.count]
                let next = corners[(index + 1) % corners.count]
                let entry = CGPoint(
                    x: corner.x + (previous.x - corner.x) * rounding,
                    y: corner.y + (previous.y - corner.y) * rounding
                )
                let exit = CGPoint(
                    x: corner.x + (next.x - corner.x) * rounding,
                    y: corner.y + (next.y - corner.y) * rounding
                )
                if index == 0 {
                    path.move(to: entry)
                } else {
                    path.addLine(to: entry)
                }
                path.addQuadCurve(to: exit, control: corner)
            }
            path.closeSubpath()
        }
    }
}

#Preview {
    TitledParchmentPanel("Stats") {
        HStack(spacing: 16) {
            HexNumber(30)
            HexNumber(24, color: .red)
            HexNumber(0)
        }
    }
    .padding(20)
    .frame(maxHeight: .infinity)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}

#Preview("Large values") {
    VStack(spacing: 16) {
        HexNumber(1_234)
        HexNumber(1_234_567, color: .red)
    }
    .padding(20)
    .background(Color(red: 0.98, green: 0.88, blue: 0.64))
}
