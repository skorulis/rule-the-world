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
