import SwiftUI

extension BannerColor {
    var color: Color { Color(red: rgb.red, green: rgb.green, blue: rgb.blue) }
}

struct BannerView: View {
    let configuration: BannerConfiguration

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 300, size.height / 220)
            context.translateBy(x: (size.width - 300 * scale) / 2, y: (size.height - 220 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            drawFlag(in: context)
            drawPole(in: context)
        }
        .aspectRatio(300.0 / 220, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            "\(configuration.backgroundColor.title) banner, \(configuration.pattern.title), " +
            "\(configuration.emblem.title) emblem"
        )
    }

    private var silhouette: Path {
        Path { path in
            path.move(to: CGPoint(x: 45, y: 40))
            path.addCurve(to: CGPoint(x: 280, y: 30), control1: CGPoint(x: 130, y: -8),
                          control2: CGPoint(x: 181, y: 85))
            path.addQuadCurve(to: CGPoint(x: 280, y: 175), control: CGPoint(x: 255, y: 102))
            path.addCurve(to: CGPoint(x: 45, y: 177), control1: CGPoint(x: 185, y: 225),
                          control2: CGPoint(x: 123, y: 136))
            path.closeSubpath()
        }
    }

    private func drawFlag(in context: GraphicsContext) {
        let ink = Color(red: 0.12, green: 0.09, blue: 0.13)
        var shadow = context
        shadow.addFilter(.shadow(color: .black.opacity(0.3), radius: 4, x: 1, y: 5))
        shadow.fill(silhouette, with: .color(configuration.backgroundColor.color))
        var fabric = context
        fabric.clip(to: silhouette)
        let pattern = BannerPatternShape(pattern: configuration.pattern)
            .path(in: CGRect(x: 42, y: 12, width: 242, height: 190))
        fabric.fill(pattern, with: .color(configuration.patternColor.color))
        fabric.stroke(pattern, with: .color(ink.opacity(0.65)), lineWidth: 2)
        fabric.fill(silhouette, with: .linearGradient(
            Gradient(stops: [
                .init(color: .white.opacity(0.22), location: 0),
                .init(color: .clear, location: 0.3),
                .init(color: .black.opacity(0.23), location: 0.53),
                .init(color: .white.opacity(0.16), location: 0.8),
                .init(color: .clear, location: 1)
            ]), startPoint: CGPoint(x: 45, y: 0), endPoint: CGPoint(x: 280, y: 60)
        ))
        fabric.stroke(silhouette, with: .color(BannerColor.gold.color), lineWidth: 9)
        context.stroke(silhouette, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineJoin: .round))
        let emblem = BannerEmblemShape(emblem: configuration.emblem)
            .path(in: CGRect(x: 123, y: 67, width: 80, height: 80))
        fabric.stroke(emblem, with: .color(ink), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
        fabric.fill(emblem, with: .linearGradient(
            Gradient(colors: [configuration.emblemColor.color, configuration.emblemColor.color.opacity(0.75)]),
            startPoint: CGPoint(x: 123, y: 67), endPoint: CGPoint(x: 203, y: 147)
        ))
        fabric.stroke(emblem, with: .color(.white.opacity(0.45)), lineWidth: 1)
    }

    private func drawPole(in context: GraphicsContext) {
        let pole = Path(roundedRect: CGRect(x: 35, y: 24, width: 11, height: 193), cornerRadius: 4)
        context.fill(pole, with: .linearGradient(
            Gradient(colors: [.gray, .white, .gray, .black]),
            startPoint: CGPoint(x: 35, y: 0), endPoint: CGPoint(x: 48, y: 0)
        ))
        context.stroke(pole, with: .color(.black.opacity(0.8)), lineWidth: 2)
        for position in [33.0, 166.0] {
            let ring = Path(roundedRect: CGRect(x: 31, y: position, width: 19, height: 12), cornerRadius: 3)
            context.fill(ring, with: .color(BannerColor.gold.color))
            context.stroke(ring, with: .color(.brown), lineWidth: 2)
        }
        let finial = Path(ellipseIn: CGRect(x: 27, y: 6, width: 26, height: 26))
        context.fill(finial, with: .linearGradient(
            Gradient(colors: [.white, .gray, BannerColor.charcoal.color]),
            startPoint: CGPoint(x: 30, y: 8), endPoint: CGPoint(x: 49, y: 30)
        ))
        context.stroke(finial, with: .color(.black.opacity(0.8)), lineWidth: 2)
    }
}

#Preview {
    ParchmentPanel {
        BannerView(configuration: .default)
    }
    .padding()
}
