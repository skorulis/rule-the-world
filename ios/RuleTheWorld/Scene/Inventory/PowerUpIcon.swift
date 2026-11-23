import SwiftUI

/// A rounded tile with a custom-drawn glyph for the power-up type,
/// tinted by rarity. Glyphs are drawn with paths so they render crisply
/// at any size without needing image assets.
struct PowerUpIcon: View {
    let type: PowerUpType
    let rarity: PowerUpRarity?
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                .fill(color.gradient.opacity(0.25))
                .overlay {
                    RoundedRectangle(cornerRadius: size * 0.25, style: .continuous)
                        .strokeBorder(color.opacity(0.6), lineWidth: 1)
                }
            PowerUpGlyph(type: type)
                .stroke(color, style: StrokeStyle(lineWidth: size * 0.07, lineCap: .round, lineJoin: .round))
                .padding(size * 0.18)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private var color: Color { rarity?.color ?? .secondary }
}

// MARK: - Glyphs

/// Shared hexagon outline helper, matching the game's hex theme.
private enum Hex {
    static func path(in rect: CGRect, inset: CGFloat = 0) -> Path {
        let rInset = rect.insetBy(dx: inset, dy: inset)
        let centX = rInset.midX, centY = rInset.midY
        let radius = min(rInset.width, rInset.height) / 2
        var path = Path()
        for corner in 0..<6 {
            let angle = Angle(degrees: Double(corner) * 60 - 90)
            let point = CGPoint(x: centX + radius * cos(angle.radians), y: centY + radius * sin(angle.radians))
            if corner == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// Hexagon containing a type-specific inner glyph:
/// revisit = circular arrow, exploration = compass star, fortification = shield.
struct PowerUpGlyph: Shape {
    let type: PowerUpType

    func path(in rect: CGRect) -> Path {
        var path = Hex.path(in: rect)
        switch type {
        case .revisit: path.addPath(revisitPath(in: rect))
        case .exploration: path.addPath(explorationPath(in: rect))
        case .fortification: path.addPath(fortificationPath(in: rect))
        }
        return path
    }

    /// Circular "again" arrow inside the hexagon.
    private func revisitPath(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX, cy = rect.midY
        let radius = min(rect.width, rect.height) * 0.22
        path.addArc(center: CGPoint(x: cx, y: cy), radius: radius,
                    startAngle: .degrees(20), endAngle: .degrees(300), clockwise: false)
        // Arrowhead at the arc's end (top-right of the circle).
        let tipAngle = Angle(degrees: 20).radians
        let tip = CGPoint(x: cx + radius * cos(tipAngle), y: cy + radius * sin(tipAngle))
        let head = radius * 0.7
        path.move(to: CGPoint(x: tip.x - head, y: tip.y - head * 0.15))
        path.addLine(to: tip)
        path.addLine(to: CGPoint(x: tip.x - head * 0.1, y: tip.y + head))
        return path
    }

    /// Four-point compass star.
    private func explorationPath(in rect: CGRect) -> Path {
        let cx = rect.midX, cy = rect.midY
        let outer = min(rect.width, rect.height) * 0.26
        let inner = outer * 0.28
        var star = Path()
        for point in 0..<8 {
            let radius = point.isMultiple(of: 2) ? outer : inner
            let angle = Angle(degrees: Double(point) * 45 - 90).radians
            let vertex = CGPoint(x: cx + radius * cos(angle), y: cy + radius * sin(angle))
            if point == 0 { star.move(to: vertex) } else { star.addLine(to: vertex) }
        }
        star.closeSubpath()
        return star
    }

    /// Shield with a center ridge.
    private func fortificationPath(in rect: CGRect) -> Path {
        let cx = rect.midX
        let top = rect.midY - rect.height * 0.22
        let halfWidth = rect.width * 0.2
        let bottom = rect.midY + rect.height * 0.26
        var shield = Path()
        shield.move(to: CGPoint(x: cx - halfWidth, y: top))
        shield.addLine(to: CGPoint(x: cx + halfWidth, y: top))
        shield.addLine(to: CGPoint(x: cx + halfWidth, y: rect.midY))
        shield.addQuadCurve(to: CGPoint(x: cx, y: bottom),
                            control: CGPoint(x: cx + halfWidth, y: bottom - rect.height * 0.08))
        shield.addQuadCurve(to: CGPoint(x: cx - halfWidth, y: rect.midY),
                            control: CGPoint(x: cx - halfWidth, y: bottom - rect.height * 0.08))
        shield.closeSubpath()
        // Shield boss: vertical center line.
        shield.move(to: CGPoint(x: cx, y: top))
        shield.addLine(to: CGPoint(x: cx, y: bottom * 0.98))
        return shield
    }
}

extension PowerUpRarity {
    var color: Color {
        switch self {
        case .common: .gray
        case .rare: .blue
        case .epic: .purple
        }
    }
}
