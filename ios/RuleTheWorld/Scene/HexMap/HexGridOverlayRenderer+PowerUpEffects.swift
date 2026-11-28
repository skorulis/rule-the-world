import CoreText
import MapKit
import SwiftUI
import os

nonisolated struct PowerUpInk {
    static let outline = UIColor(red: 0.18, green: 0.10, blue: 0.06, alpha: 1)
    static let gold = UIColor(red: 1, green: 0.76, blue: 0.25, alpha: 1)
    static let highlight = UIColor(red: 1, green: 0.94, blue: 0.68, alpha: 1)

    static func tint(_ type: PowerUpType) -> UIColor {
        switch type {
        case .attack: UIColor(red: 0.88, green: 0.22, blue: 0.12, alpha: 1)
        case .defend: UIColor(red: 0.22, green: 0.63, blue: 0.92, alpha: 1)
        case .explore: UIColor(red: 0.30, green: 0.76, blue: 0.30, alpha: 1)
        }
    }
}

nonisolated struct PowerUpEffectGeometry {
    let path: CGPath
    let center: CGPoint
    let emblem: CGFloat
    let zoomScale: MKZoomScale
}

extension HexGridOverlayRenderer {
    func drawPowerUps(in mapRect: MKMapRect, hexEdge: CGFloat, zoomScale: MKZoomScale, context: CGContext) {
        let presentation = state.withLock { ($0.powerUps.effects, $0.reduceMotion, $0.snapshot, $0.mode) }
        let now = Date.now
        let bounds = rect(for: mapRect).insetBy(dx: -180 / zoomScale, dy: -180 / zoomScale)
        for effect in presentation.0 where !effect.isExpired(at: now, reduceMotion: presentation.1) {
            for (index, cell) in effect.cells.enumerated() {
                let boundary = grid.boundary(of: cell)
                guard !boundary.isEmpty else { continue }
                let level = presentation.3 == .exploration
                    ? (presentation.2.states[cell] == .rivalOwned ? 0 : presentation.2.visitLevels[cell] ?? 0)
                    : presentation.2.levels[cell] ?? 0
                let height = lift(level, hexEdge: hexEdge)
                let points = boundary.map { coordinate in
                    let point = point(for: MKMapPoint(coordinate))
                    return CGPoint(x: point.x, y: point.y - height)
                }
                let center = CGPoint(
                    x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                    y: points.map(\.y).reduce(0, +) / CGFloat(points.count)
                )
                guard bounds.contains(center) else { continue }
                let path = CGMutablePath()
                path.addLines(between: points)
                path.closeSubpath()
                let radius = points.map { hypot($0.x - center.x, $0.y - center.y) }.max() ?? hexEdge
                let emblem = min(max(radius * 0.6, 16 / zoomScale), 36 / zoomScale)
                context.saveGState()
                if effect.phase == .pending {
                    context.setAlpha(0.55)
                    context.setLineDash(phase: 0, lengths: [5 / zoomScale, 4 / zoomScale])
                    powerUpStroke(path, color: PowerUpInk.tint(effect.type), width: 2 / zoomScale, in: context)
                } else {
                    let progress = effect.progress(for: index, at: now, reduceMotion: presentation.1)
                    if (0..<1).contains(progress) {
                        drawPowerUpImpact(
                            effect, progress: progress, reduceMotion: presentation.1,
                            geometry: PowerUpEffectGeometry(
                                path: path, center: center, emblem: emblem, zoomScale: zoomScale
                            ), context: context
                        )
                    }
                }
                context.restoreGState()
            }
        }
    }

    private func drawPowerUpImpact(
        _ effect: PowerUpEffect, progress: Double, reduceMotion: Bool,
        geometry: PowerUpEffectGeometry, context: CGContext
    ) {
        let (path, center, emblem, zoomScale) = (geometry.path, geometry.center, geometry.emblem, geometry.zoomScale)
        let time = CGFloat(progress)
        let fade = min(1, (1 - time) * 4)
        context.setAlpha(fade)
        let tint = PowerUpInk.tint(effect.type)
        context.saveGState()
        context.setShadow(offset: .zero, blur: 5 / zoomScale, color: tint.withAlphaComponent(0.5).cgColor)
        let outline = effect.type == .defend && !reduceMotion
            ? Path(path).trimmedPath(from: 0, to: min(time / 0.4, 1)).cgPath : path
        powerUpStroke(outline, color: tint, width: 2.5 / zoomScale, in: context)
        if effect.type == .defend && !reduceMotion {
            let trace = min(time / 0.4, 1)
            let glint = Path(path).trimmedPath(from: max(0, trace - 0.2), to: trace).cgPath
            powerUpStroke(glint, color: PowerUpInk.highlight, width: 1.5 / zoomScale, in: context)
        }
        context.restoreGState()
        if !reduceMotion {
            drawPowerUpRipples(effect.type, geometry: geometry, time: time, context: context)
        }
        context.saveGState()
        context.translateBy(x: center.x, y: center.y)
        context.scaleBy(x: emblem, y: emblem)
        let flourish = effect.rarity == .common ? 5 : (effect.rarity == .rare ? 7 : 9)
        if !reduceMotion {
            drawPowerUpSparks(type: effect.type, count: flourish, time: time, context: context)
        }
        drawPowerUpEmblem(type: effect.type, time: time, reduceMotion: reduceMotion, context: context)
        context.restoreGState()
        if reduceMotion || time > 0.18 {
            drawPowerUpScore(
                effect.bonus, geometry: geometry, time: reduceMotion ? 0 : time, context: context
            )
        }
    }

    func powerUpStroke(_ path: CGPath, color: UIColor, width: CGFloat, in context: CGContext) {
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.addPath(path)
        context.setStrokeColor(PowerUpInk.outline.cgColor)
        context.setLineWidth(width * 1.8)
        context.strokePath()
        context.addPath(path)
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.strokePath()
    }

    private func drawPowerUpRipples(
        _ type: PowerUpType, geometry: PowerUpEffectGeometry, time: CGFloat, context: CGContext
    ) {
        let (path, center, zoom) = (geometry.path, geometry.center, geometry.zoomScale)
        let count = type == .explore ? 2 : 1
        for index in 0..<count {
            let phase = max(0, min(1, (time - CGFloat(index) * 0.16) / 0.7))
            guard phase > 0, phase < 1 else { continue }
            context.saveGState()
            context.setAlpha((1 - phase) * 0.7)
            context.translateBy(x: center.x, y: center.y)
            let scale: CGFloat = type == .defend ? 1 + phase * 0.12 : 1 + phase * 0.55
            context.scaleBy(x: scale, y: scale)
            context.translateBy(x: -center.x, y: -center.y)
            powerUpStroke(path, color: index == 0 ? PowerUpInk.tint(type) : PowerUpInk.gold,
                          width: 2 / zoom, in: context)
            context.restoreGState()
        }
    }

    private func drawPowerUpScore(
        _ bonus: Int, geometry: PowerUpEffectGeometry, time: CGFloat, context: CGContext
    ) {
        let (center, emblem, zoom) = (geometry.center, geometry.emblem, geometry.zoomScale)
        let font = CTFontCreateWithName("Georgia-Bold" as CFString, 17 / zoom, nil)
        let text = NSAttributedString(string: "+\(bonus)", attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): PowerUpInk.highlight.cgColor,
            NSAttributedString.Key(kCTStrokeColorAttributeName as String): PowerUpInk.outline.cgColor,
            NSAttributedString.Key(kCTStrokeWidthAttributeName as String): -5,
        ])
        let line = CTLineCreateWithAttributedString(text as CFAttributedString)
        let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
        context.saveGState()
        context.translateBy(x: center.x - width / 2, y: center.y - emblem * 1.15 - time * 16 / zoom)
        context.scaleBy(x: 1, y: -1)
        context.textMatrix = .identity
        context.textPosition = .zero
        context.setShadow(offset: .zero, blur: 2 / zoom, color: PowerUpInk.outline.cgColor)
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
