import SwiftUI

struct TwinkleStar: View {
    enum Shape {
        case fourPointStar
        case circle
    }

    var shape: Shape = .fourPointStar
    var size: CGFloat = 12
    var color = Color(red: 0.55, green: 0.96, blue: 1)
    var duration: TimeInterval = 2.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var phase = Double.random(in: 0..<(2 * .pi))

    var body: some View {
        TimelineView(.animation(
            minimumInterval: 1.0 / 30,
            paused: reduceMotion || !isVisible || scenePhase != .active
        )) { context in
            let period = max(duration, 0.1)
            let time = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
            let glow = reduceMotion ? 0.5 : (sin(time / period * 2 * .pi + phase) + 1) / 2

            ZStack {
                silhouette
                    .fill(color)
                    .blur(radius: size * (0.4 + glow * 0.4))
                    .opacity(0.3 + glow * 0.6)
                silhouette
                    .fill(color)
                    .shadow(color: color.opacity(0.4 + glow * 0.5), radius: size * (0.15 + glow * 0.25))
                silhouette
                    .fill(.white.opacity(0.9))
                    .scaleEffect(0.65)
            }
            .frame(width: size, height: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
    }

    private var silhouette: AnyShape {
        switch shape {
        case .fourPointStar: AnyShape(FourPointStarShape())
        case .circle: AnyShape(Circle())
        }
    }
}

private struct FourPointStarShape: Shape {
    func path(in rect: CGRect) -> Path {
        let insetX = rect.width * 0.12
        let insetY = rect.height * 0.12
        return Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.midY),
                control: CGPoint(x: rect.midX + insetX, y: rect.midY - insetY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.maxY),
                control: CGPoint(x: rect.midX + insetX, y: rect.midY + insetY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.midY),
                control: CGPoint(x: rect.midX - insetX, y: rect.midY + insetY)
            )
            path.addQuadCurve(
                to: CGPoint(x: rect.midX, y: rect.minY),
                control: CGPoint(x: rect.midX - insetX, y: rect.midY - insetY)
            )
            path.closeSubpath()
        }
    }
}

#Preview {
    HStack(spacing: 36) {
        TwinkleStar(size: 10)
        TwinkleStar(size: 22, duration: 3)
        TwinkleStar(shape: .circle, size: 6)
        TwinkleStar(shape: .circle, size: 12, duration: 2)
    }
    .padding(48)
    .background(LinearGradient(colors: [.indigo, .blue, .cyan], startPoint: .top, endPoint: .bottom))
}

#Preview("Reduce Motion") {
    HStack(spacing: 36) {
        TwinkleStar(size: 22)
        TwinkleStar(shape: .circle, size: 10)
    }
    .padding(48)
    .background(Color(red: 0.1, green: 0.18, blue: 0.38))
}
