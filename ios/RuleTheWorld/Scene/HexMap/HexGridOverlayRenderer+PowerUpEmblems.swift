import MapKit

extension HexGridOverlayRenderer {
    func drawPowerUpEmblem(type: PowerUpType, time: CGFloat, reduceMotion: Bool, context: CGContext) {
        context.saveGState()
        switch type {
        case .attack:
            drawPowerUpBlades(time: time, reduceMotion: reduceMotion, context: context)
        case .defend:
            if !reduceMotion {
                let arrival = min(time / 0.35, 1)
                let bounce = 0.5 * (1 - arrival) * (1 - arrival) * cos(arrival * 2 * .pi)
                context.translateBy(x: 0, y: bounce)
            }
            drawPowerUpShield(context: context)
        case .explore:
            if !reduceMotion {
                let opening = min(time / 0.35, 1)
                let scale = 0.25 + 0.75 * opening + sin(opening * .pi) * 0.16
                context.scaleBy(x: scale, y: scale)
                context.rotate(by: (1 - opening) * -.pi / 6)
            }
            drawPowerUpCompass(context: context)
        }
        context.restoreGState()
    }

    private func drawPowerUpBlades(time: CGFloat, reduceMotion: Bool, context: CGContext) {
        for index in 0..<2 {
            let arrival = reduceMotion ? 1 : max(0, min(1, (time - CGFloat(index) * 0.12) / 0.24))
            guard arrival > 0 else { continue }
            context.saveGState()
            context.rotate(by: index == 0 ? .pi / 4 : -.pi / 4)
            context.translateBy(x: 0, y: (1 - arrival) * 0.8)
            context.setAlpha(arrival * min(1, (1 - time) * 4))
            let blade = CGMutablePath()
            blade.addLines(between: [
                CGPoint(x: -0.14, y: 0.42), CGPoint(x: -0.14, y: -0.58),
                CGPoint(x: 0, y: -0.95), CGPoint(x: 0.14, y: -0.58), CGPoint(x: 0.14, y: 0.42),
            ])
            blade.closeSubpath()
            powerUpFill(blade, top: PowerUpInk.highlight, bottom: PowerUpInk.gold, context: context)
            let facet = CGMutablePath()
            facet.addLines(between: [CGPoint(x: 0, y: -0.9), CGPoint(x: 0.12, y: -0.55),
                                     CGPoint(x: 0.12, y: 0.4), CGPoint(x: 0, y: 0.4),
            ])
            facet.closeSubpath()
            context.addPath(facet)
            context.setFillColor(PowerUpInk.tint(.attack).withAlphaComponent(0.65).cgColor)
            context.fillPath()
            let guardPath = CGPath(roundedRect: CGRect(x: -0.32, y: 0.36, width: 0.64, height: 0.16),
                                   cornerWidth: 0.04, cornerHeight: 0.04, transform: nil)
            powerUpFill(guardPath, top: PowerUpInk.gold, bottom: PowerUpInk.tint(.attack), context: context)
            let handle = CGPath(roundedRect: CGRect(x: -0.08, y: 0.52, width: 0.16, height: 0.3),
                                cornerWidth: 0.03, cornerHeight: 0.03, transform: nil)
            powerUpFill(handle, top: PowerUpInk.gold, bottom: PowerUpInk.tint(.attack), context: context)
            context.restoreGState()
        }
        if !reduceMotion && time > 0.18 && time < 0.55 {
            context.saveGState()
            let scale = sin((time - 0.18) / 0.37 * .pi) * 0.45
            context.scaleBy(x: scale, y: scale)
            powerUpFill(powerUpStar(points: 8), top: PowerUpInk.highlight, bottom: PowerUpInk.gold, context: context)
            context.restoreGState()
        }
    }

    private func drawPowerUpShield(context: CGContext) {
        let shield = CGMutablePath()
        shield.move(to: CGPoint(x: 0, y: -0.85))
        shield.addQuadCurve(to: CGPoint(x: 0.75, y: -0.58), control: CGPoint(x: 0.4, y: -0.57))
        shield.addCurve(to: CGPoint(x: 0, y: 0.95), control1: CGPoint(x: 0.82, y: 0.35),
                        control2: CGPoint(x: 0.46, y: 0.73))
        shield.addCurve(to: CGPoint(x: -0.75, y: -0.58), control1: CGPoint(x: -0.46, y: 0.73),
                        control2: CGPoint(x: -0.82, y: 0.35))
        shield.addQuadCurve(to: CGPoint(x: 0, y: -0.85), control: CGPoint(x: -0.4, y: -0.57))
        shield.closeSubpath()
        powerUpFill(shield, top: PowerUpInk.highlight, bottom: PowerUpInk.gold, context: context)
        context.saveGState()
        context.scaleBy(x: 0.78, y: 0.78)
        powerUpFill(shield, top: PowerUpInk.tint(.defend),
                    bottom: UIColor(red: 0.1, green: 0.25, blue: 0.46, alpha: 1), context: context)
        context.restoreGState()
        let tower = CGMutablePath()
        tower.addLines(between: [
            CGPoint(x: -0.27, y: -0.4), CGPoint(x: -0.12, y: -0.4), CGPoint(x: -0.12, y: -0.25),
            CGPoint(x: 0.12, y: -0.25), CGPoint(x: 0.12, y: -0.4), CGPoint(x: 0.27, y: -0.4),
            CGPoint(x: 0.27, y: -0.08), CGPoint(x: 0.18, y: -0.02), CGPoint(x: 0.23, y: 0.46),
            CGPoint(x: -0.23, y: 0.46), CGPoint(x: -0.18, y: -0.02), CGPoint(x: -0.27, y: -0.08),
        ])
        tower.closeSubpath()
        powerUpFill(tower, top: PowerUpInk.highlight, bottom: PowerUpInk.gold, context: context)
        context.setFillColor(PowerUpInk.outline.cgColor)
        context.fill(CGRect(x: -0.06, y: 0.12, width: 0.12, height: 0.22))
    }

    private func drawPowerUpCompass(context: CGContext) {
        let star = powerUpStar(points: 8)
        powerUpFill(star, top: PowerUpInk.highlight, bottom: PowerUpInk.gold, context: context)
        for index in 0..<8 {
            let angle = CGFloat(index) * .pi / 4 - .pi / 2
            let radius: CGFloat = index.isMultiple(of: 2) ? 1 : 0.68
            let facet = CGMutablePath()
            facet.move(to: .zero)
            facet.addLine(to: CGPoint(x: cos(angle) * radius, y: sin(angle) * radius))
            facet.addLine(to: CGPoint(x: cos(angle + .pi / 8) * 0.3, y: sin(angle + .pi / 8) * 0.3))
            facet.closeSubpath()
            context.addPath(facet)
            context.setFillColor(PowerUpInk.outline.withAlphaComponent(0.25).cgColor)
            context.fillPath()
        }
        context.setFillColor(PowerUpInk.highlight.cgColor)
        context.fillEllipse(in: CGRect(x: -0.08, y: -0.08, width: 0.16, height: 0.16))
    }

    func drawPowerUpSparks(type: PowerUpType, count: Int, time: CGFloat, context: CGContext) {
        let progress = max(0, min(1, (time - 0.15) / 0.7))
        guard progress > 0, progress < 1 else { return }
        for index in 0..<count {
            let angle = CGFloat(index) * 2 * .pi / CGFloat(count) + 0.3
            let distance = 0.8 + progress * (index.isMultiple(of: 2) ? 1.1 : 0.7)
            context.saveGState()
            context.setAlpha((1 - progress) * 0.9)
            context.translateBy(x: cos(angle) * distance, y: sin(angle) * distance)
            let size = (type == .attack ? 0.14 : 0.18) * (1 - progress * 0.5)
            context.scaleBy(x: size, y: size)
            if type == .attack { context.rotate(by: angle) }
            powerUpFill(powerUpStar(points: type == .attack ? 3 : 4),
                        top: PowerUpInk.highlight, bottom: PowerUpInk.gold, context: context)
            context.restoreGState()
        }
    }

    private func powerUpStar(points count: Int) -> CGPath {
        let path = CGMutablePath()
        for index in 0..<(count * 2) {
            let angle = CGFloat(index) * .pi / CGFloat(count) - .pi / 2
            let radius: CGFloat = !index.isMultiple(of: 2) ? 0.3
                : (count == 8 && !(index / 2).isMultiple(of: 2) ? 0.68 : 1)
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func powerUpFill(_ path: CGPath, top: UIColor, bottom: UIColor, context: CGContext) {
        context.saveGState()
        context.addPath(path)
        context.clip()
        if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                     colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1]) {
            context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: -1), end: CGPoint(x: 0, y: 1),
                                       options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        context.restoreGState()
        context.addPath(path)
        context.setStrokeColor(PowerUpInk.outline.cgColor)
        context.setLineJoin(.round)
        context.setLineWidth(0.065)
        context.strokePath()
    }
}
