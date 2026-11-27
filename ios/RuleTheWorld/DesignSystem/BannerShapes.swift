import SwiftUI

struct BannerPatternShape: Shape {
    let pattern: BannerPattern

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch pattern {
        case .solid:
            break
        case .horizontalSplit:
            path.addRect(CGRect(x: 0, y: 0.5, width: 1, height: 0.5))
        case .verticalSplit:
            path.addRect(CGRect(x: 0.5, y: 0, width: 0.5, height: 1))
        case .diagonalBand:
            path.addLines([
                CGPoint(x: -0.2, y: 0.8), CGPoint(x: 0.8, y: -0.2),
                CGPoint(x: 1.2, y: 0.2), CGPoint(x: 0.2, y: 1.2)
            ])
            path.closeSubpath()
        case .cross:
            path.addLines([
                CGPoint(x: 0.4, y: 0), CGPoint(x: 0.6, y: 0), CGPoint(x: 0.6, y: 0.4),
                CGPoint(x: 1, y: 0.4), CGPoint(x: 1, y: 0.6), CGPoint(x: 0.6, y: 0.6),
                CGPoint(x: 0.6, y: 1), CGPoint(x: 0.4, y: 1), CGPoint(x: 0.4, y: 0.6),
                CGPoint(x: 0, y: 0.6), CGPoint(x: 0, y: 0.4), CGPoint(x: 0.4, y: 0.4)
            ])
            path.closeSubpath()
        case .chevron:
            path.addLines([
                CGPoint(x: 0, y: 0.7), CGPoint(x: 0.5, y: 0.15), CGPoint(x: 1, y: 0.7),
                CGPoint(x: 1, y: 1), CGPoint(x: 0.5, y: 0.45), CGPoint(x: 0, y: 1)
            ])
            path.closeSubpath()
        }
        return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

struct BannerEmblemShape: Shape {
    let emblem: BannerEmblem

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch emblem {
        case .none:
            break
        case .crown:
            path.addLines([
                CGPoint(x: 0.12, y: 0.28), CGPoint(x: 0.34, y: 0.47), CGPoint(x: 0.5, y: 0.08),
                CGPoint(x: 0.66, y: 0.47), CGPoint(x: 0.88, y: 0.28),
                CGPoint(x: 0.78, y: 0.82), CGPoint(x: 0.22, y: 0.82)
            ])
            path.closeSubpath()
            path.addRoundedRect(in: CGRect(x: 0.2, y: 0.85, width: 0.6, height: 0.08),
                                cornerSize: CGSize(width: 0.02, height: 0.02))
        case .shield:
            path.move(to: CGPoint(x: 0.5, y: 0.04))
            path.addQuadCurve(to: CGPoint(x: 0.9, y: 0.2), control: CGPoint(x: 0.72, y: 0.2))
            path.addCurve(to: CGPoint(x: 0.5, y: 0.96), control1: CGPoint(x: 0.91, y: 0.66),
                          control2: CGPoint(x: 0.76, y: 0.82))
            path.addCurve(to: CGPoint(x: 0.1, y: 0.2), control1: CGPoint(x: 0.24, y: 0.82),
                          control2: CGPoint(x: 0.09, y: 0.66))
            path.addQuadCurve(to: CGPoint(x: 0.5, y: 0.04), control: CGPoint(x: 0.28, y: 0.2))
            path.closeSubpath()
        case .sword:
            path.addLines([
                CGPoint(x: 0.45, y: 0.66), CGPoint(x: 0.42, y: 0.2), CGPoint(x: 0.5, y: 0.02),
                CGPoint(x: 0.58, y: 0.2), CGPoint(x: 0.55, y: 0.66), CGPoint(x: 0.8, y: 0.62),
                CGPoint(x: 0.8, y: 0.73), CGPoint(x: 0.56, y: 0.75), CGPoint(x: 0.56, y: 0.94),
                CGPoint(x: 0.44, y: 0.94), CGPoint(x: 0.44, y: 0.75),
                CGPoint(x: 0.2, y: 0.73), CGPoint(x: 0.2, y: 0.62)
            ])
            path.closeSubpath()
        case .star, .compass:
            let points = emblem == .star ? 5 : 8
            for index in 0..<(points * 2) {
                let angle = Double(index) * .pi / Double(points) - .pi / 2
                let radius = index.isMultiple(of: 2) ? 0.47 : (emblem == .star ? 0.21 : 0.13)
                let point = CGPoint(x: 0.5 + cos(angle) * radius, y: 0.5 + sin(angle) * radius)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            if emblem == .compass {
                path.addEllipse(in: CGRect(x: 0.42, y: 0.42, width: 0.16, height: 0.16))
            }
        }
        return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }
}

#Preview("Patterns") {
    HStack {
        ForEach(BannerPattern.allCases, id: \.self) { pattern in
            BannerPatternShape(pattern: pattern)
                .fill(.orange)
                .frame(width: 40, height: 40)
                .background(.blue)
                .clipped()
        }
    }
    .padding()
}

#Preview("Emblems") {
    HStack {
        ForEach(BannerEmblem.allCases, id: \.self) { emblem in
            BannerEmblemShape(emblem: emblem)
                .fill(.orange)
                .frame(width: 40, height: 40)
        }
    }
    .padding()
}
