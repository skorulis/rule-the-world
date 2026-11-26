import SwiftUI

struct ParchmentPanel<Content: View>: View {
    private let contentInsets: EdgeInsets
    private let content: Content
    private let borderWidth: CGFloat = 16

    init(
        contentInsets: EdgeInsets = EdgeInsets(top: 20, leading: 20, bottom: 20, trailing: 20),
        @ViewBuilder content: () -> Content
    ) {
        self.contentInsets = contentInsets
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            content
        }
        .padding(contentInsets)
        .padding(borderWidth)
        .background {
            ParchmentPanelBackground(borderWidth: borderWidth)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct ParchmentPanelBackground: View {
    let borderWidth: CGFloat
    private let ink = Color(red: 0.18, green: 0.13, blue: 0.12)
    private let steel = Color(red: 0.52, green: 0.49, blue: 0.46)
    private let steelHighlight = Color(red: 0.78, green: 0.75, blue: 0.67)

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 2, dy: 2)
            let frame = Path(roundedRect: rect, cornerRadius: 8)
            var shadow = context
            shadow.translateBy(x: 0, y: 5)
            shadow.fill(frame, with: .color(ink))
            context.fill(frame, with: .linearGradient(
                Gradient(colors: [steelHighlight, steel, ink, steel]),
                startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)
            ))
            context.stroke(frame, with: .color(ink), lineWidth: 3)
            context.stroke(
                Path(roundedRect: rect.insetBy(dx: 3, dy: 3), cornerRadius: 5),
                with: .color(steelHighlight.opacity(0.8)), lineWidth: 1.5
            )

            let paperRect = CGRect(origin: .zero, size: size).insetBy(dx: borderWidth, dy: borderWidth)
            let paper = paperPath(in: paperRect)
            context.fill(paper, with: .linearGradient(
                Gradient(colors: [
                    Color(red: 0.76, green: 0.55, blue: 0.31),
                    Color(red: 0.98, green: 0.88, blue: 0.64),
                    Color(red: 0.94, green: 0.81, blue: 0.55),
                    Color(red: 0.74, green: 0.52, blue: 0.3),
                ]),
                startPoint: CGPoint(x: 0, y: paperRect.minY),
                endPoint: CGPoint(x: 0, y: paperRect.maxY)
            ))
            context.fill(paper, with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.94, blue: 0.75).opacity(0.75), .clear]),
                center: CGPoint(x: paperRect.midX, y: paperRect.midY),
                startRadius: 0, endRadius: max(paperRect.width, paperRect.height) * 0.65
            ))
            context.stroke(paper, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
            context.stroke(
                paper, with: .color(Color.brown.opacity(0.25)),
                style: StrokeStyle(lineWidth: 7, lineJoin: .round)
            )
            drawCorners(in: context, rect: rect)
            drawRivets(in: context, rect: rect)
        }
        .shadow(color: .black.opacity(0.3), radius: 5, y: 4)
    }

    private func paperPath(in rect: CGRect) -> Path {
        let notch: CGFloat = 5
        return Path { path in
            path.move(to: CGPoint(x: rect.minX + notch, y: rect.minY))
            path.addLines([
                CGPoint(x: rect.maxX - notch * 2, y: rect.minY + 1),
                CGPoint(x: rect.maxX - notch, y: rect.minY + notch),
                CGPoint(x: rect.maxX, y: rect.minY + notch),
                CGPoint(x: rect.maxX - 1, y: rect.midY - notch),
                CGPoint(x: rect.maxX - notch, y: rect.midY),
                CGPoint(x: rect.maxX, y: rect.midY + notch),
                CGPoint(x: rect.maxX - 2, y: rect.maxY - notch),
                CGPoint(x: rect.maxX - notch * 2, y: rect.maxY),
                CGPoint(x: rect.minX + notch, y: rect.maxY - 1),
                CGPoint(x: rect.minX, y: rect.maxY - notch * 2),
                CGPoint(x: rect.minX + 2, y: rect.midY + notch),
                CGPoint(x: rect.minX + notch, y: rect.midY),
                CGPoint(x: rect.minX, y: rect.midY - notch),
                CGPoint(x: rect.minX + 1, y: rect.minY + notch),
            ])
            path.closeSubpath()
        }
    }

    private func drawCorners(in context: GraphicsContext, rect: CGRect) {
        for right in [false, true] {
            for bottom in [false, true] {
                var corner = context
                corner.translateBy(x: right ? rect.maxX : rect.minX, y: bottom ? rect.maxY : rect.minY)
                corner.scaleBy(x: right ? -1 : 1, y: bottom ? -1 : 1)
                let plate = Path { path in
                    path.move(to: .zero)
                    path.addLines([
                        CGPoint(x: 40, y: 0), CGPoint(x: 30, y: 13),
                        CGPoint(x: 15, y: 15), CGPoint(x: 13, y: 30), CGPoint(x: 0, y: 40),
                    ])
                    path.closeSubpath()
                }
                corner.fill(plate, with: .linearGradient(
                    Gradient(colors: [steelHighlight, steel]),
                    startPoint: .zero, endPoint: CGPoint(x: 28, y: 30)
                ))
                corner.stroke(plate, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }

    private func drawRivets(in context: GraphicsContext, rect: CGRect) {
        let inset: CGFloat = 7
        let positions = [
            CGPoint(x: rect.minX + inset, y: rect.minY + inset),
            CGPoint(x: rect.maxX - inset, y: rect.minY + inset),
            CGPoint(x: rect.minX + inset, y: rect.maxY - inset),
            CGPoint(x: rect.maxX - inset, y: rect.maxY - inset),
            CGPoint(x: rect.midX, y: rect.minY + inset),
            CGPoint(x: rect.midX, y: rect.maxY - inset),
        ]
        for position in positions {
            let rivet = Path(ellipseIn: CGRect(x: position.x - 4, y: position.y - 4, width: 8, height: 8))
            context.fill(rivet, with: .linearGradient(
                Gradient(colors: [steelHighlight, steel, ink]),
                startPoint: CGPoint(x: position.x - 2, y: position.y - 4),
                endPoint: CGPoint(x: position.x + 2, y: position.y + 4)
            ))
            context.stroke(rivet, with: .color(ink), lineWidth: 1.5)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ParchmentPanel {
            VStack(spacing: 16) {
                Text("Your next adventure").font(.title2.bold())
                Text("A reusable panel that grows with its content.")
                Button("Continue") { }
                    .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: .infinity)
        }
        ParchmentPanel {
            Text("A smaller panel")
        }
    }
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(.blue.gradient)
}
