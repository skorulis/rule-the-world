import CoreText
import SwiftUI

struct DecorativeTextStyle {
    var face: [Color]
    var outline: Color
    var rim: Color
    var bevel: Color
    var highlight: Color
    var extrusion: Color
    var outlineWidth: CGFloat = 0.085
    var depth: CGFloat = 0.1

    static let royalGold = DecorativeTextStyle(
        face: [
            Color(red: 1, green: 0.97, blue: 0.83),
            Color(red: 0.76, green: 0.72, blue: 0.62),
            Color(red: 1, green: 0.94, blue: 0.76),
            Color(red: 0.58, green: 0.53, blue: 0.44),
        ],
        outline: Color(red: 0.12, green: 0.08, blue: 0.06),
        rim: Color(red: 0.89, green: 0.66, blue: 0.3),
        bevel: Color(red: 0.32, green: 0.22, blue: 0.13),
        highlight: Color(red: 1, green: 0.94, blue: 0.7),
        extrusion: Color(red: 0.25, green: 0.21, blue: 0.22)
    )
}

struct DecorativeText: View {
    let text: String
    let fontSize: CGFloat
    let style: DecorativeTextStyle
    private let glyphs: Path
    private let bounds: CGRect

    init(_ text: String, fontSize: CGFloat = 64, style: DecorativeTextStyle = .royalGold) {
        self.text = text
        self.fontSize = fontSize
        self.style = style
        let path = Self.glyphPath(for: text, size: fontSize)
        glyphs = Path(path)
        bounds = path.boundingBoxOfPath
    }

    var body: some View {
        let padding = fontSize * style.outlineWidth
        let depth = fontSize * style.depth
        let width = max(1, bounds.width + padding * 2)
        let height = max(1, bounds.height + padding * 2 + depth)

        Canvas { context, size in
            let scale = min(size.width / width, size.height / height)
            context.translateBy(
                x: (size.width - width * scale) / 2,
                y: (size.height - height * scale) / 2
            )
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: padding - bounds.minX, y: padding - bounds.minY)
            draw(in: context, depth: depth)
        }
        .aspectRatio(width / height, contentMode: .fit)
        .frame(maxWidth: width)
        .accessibilityLabel(Text(text))
        .accessibilityAddTraits(.isStaticText)
    }

    private func draw(in context: GraphicsContext, depth: CGFloat) {
        let outlineWidth = fontSize * style.outlineWidth
        let stroke = StrokeStyle(lineWidth: outlineWidth * 2, lineJoin: .round)
        for step in stride(from: 8, through: 1, by: -1) {
            var layer = context
            layer.translateBy(x: 0, y: depth * CGFloat(step) / 8)
            layer.stroke(glyphs, with: .color(style.outline), style: stroke)
            layer.fill(glyphs, with: .color(style.extrusion))
        }
        context.stroke(glyphs, with: .color(style.outline), style: stroke)
        context.stroke(
            glyphs, with: .color(style.rim),
            style: StrokeStyle(lineWidth: outlineWidth * 1.35, lineJoin: .round)
        )
        context.stroke(
            glyphs, with: .color(style.bevel),
            style: StrokeStyle(lineWidth: outlineWidth * 0.65, lineJoin: .round)
        )
        context.fill(
            glyphs,
            with: .linearGradient(
                Gradient(colors: style.face),
                startPoint: CGPoint(x: 0, y: bounds.minY),
                endPoint: CGPoint(x: 0, y: bounds.maxY)
            )
        )
        var highlight = context
        highlight.clip(to: glyphs)
        highlight.translateBy(x: 0, y: fontSize * 0.015)
        highlight.stroke(
            glyphs, with: .color(style.highlight),
            style: StrokeStyle(lineWidth: fontSize * 0.025, lineJoin: .round)
        )
    }

    private static let displayFont: CGFont? = {
        guard let url = Bundle.main.url(forResource: "CinzelDecorative-Black", withExtension: "ttf"),
              let provider = CGDataProvider(url: url as CFURL) else { return nil }
        return CGFont(provider)
    }()

    private static func glyphPath(for text: String, size: CGFloat) -> CGPath {
        let font = displayFont.map { CTFontCreateWithGraphicsFont($0, size, nil, nil) }
            ?? CTFontCreateWithName("Georgia-Bold" as CFString, size, nil)
        let attributed = NSAttributedString(
            string: text,
            attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font]
        )
        let line = CTLineCreateWithAttributedString(attributed)
        let path = CGMutablePath()
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            let runFont = CTFontCreateForString(font, text as CFString, CTRunGetStringRange(run))
            let count = CTRunGetGlyphCount(run)
            var glyphs = [CGGlyph](repeating: 0, count: count)
            var positions = [CGPoint](repeating: .zero, count: count)
            CTRunGetGlyphs(run, CFRange(location: 0, length: 0), &glyphs)
            CTRunGetPositions(run, CFRange(location: 0, length: 0), &positions)
            for index in 0..<count {
                guard let glyph = CTFontCreatePathForGlyph(runFont, glyphs[index], nil) else { continue }
                path.addPath(glyph, transform: CGAffineTransform(
                    a: 1, b: 0, c: 0, d: -1,
                    tx: positions[index].x, ty: -positions[index].y
                ))
            }
        }
        return path
    }
}

#Preview {
    VStack(spacing: 24) {
        DecorativeText("RULE THE", fontSize: 48)
        DecorativeText("WORLD", fontSize: 72)
        DecorativeText("VICTORY", fontSize: 40)
    }
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(.blue.gradient)
}
