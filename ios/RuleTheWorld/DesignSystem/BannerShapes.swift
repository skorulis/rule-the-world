import SwiftUI

struct BannerPatternShape: Shape {
    let pattern: BannerPattern

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch pattern {
        case .solid, .horizontalSplit, .verticalSplit, .diagonalBand, .cross, .chevron,
             .fess, .pale, .bendSinister, .saltire:
            addBandsAndDivisions(to: &path)
        case .chief, .quarters, .barry, .paly, .checkered, .lozenge, .roundel, .rays:
            addFieldsAndCharges(to: &path)
        }
        return path.applying(CGAffineTransform(scaleX: rect.width, y: rect.height)
            .concatenating(CGAffineTransform(translationX: rect.minX, y: rect.minY)))
    }

    private func addBandsAndDivisions(to path: inout Path) {
        switch pattern {
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
        case .fess:
            path.addRect(CGRect(x: 0, y: 0.35, width: 1, height: 0.3))
        case .pale:
            path.addRect(CGRect(x: 0.35, y: 0, width: 0.3, height: 1))
        case .bendSinister:
            path.addLines([
                CGPoint(x: 1.2, y: 0.8), CGPoint(x: 0.2, y: -0.2),
                CGPoint(x: -0.2, y: 0.2), CGPoint(x: 0.8, y: 1.2)
            ])
            path.closeSubpath()
        case .saltire:
            path.addLines([
                CGPoint(x: -0.2, y: 0.8), CGPoint(x: 0.8, y: -0.2),
                CGPoint(x: 1.2, y: 0.2), CGPoint(x: 0.2, y: 1.2)
            ])
            path.closeSubpath()
            path.addLines([
                CGPoint(x: 1.2, y: 0.8), CGPoint(x: 0.2, y: -0.2),
                CGPoint(x: -0.2, y: 0.2), CGPoint(x: 0.8, y: 1.2)
            ])
            path.closeSubpath()
        default:
            break
        }
    }

    private func addFieldsAndCharges(to path: inout Path) {
        switch pattern {
        case .chief:
            path.addRect(CGRect(x: 0, y: 0, width: 1, height: 0.28))
        case .quarters:
            path.addRect(CGRect(x: 0.5, y: 0, width: 0.5, height: 0.5))
            path.addRect(CGRect(x: 0, y: 0.5, width: 0.5, height: 0.5))
        case .barry:
            for index in 0..<3 {
                path.addRect(CGRect(x: 0, y: 0.11 + 0.3 * Double(index), width: 1, height: 0.18))
            }
        case .paly:
            for index in 0..<3 {
                path.addRect(CGRect(x: 0.11 + 0.3 * Double(index), y: 0, width: 0.18, height: 1))
            }
        case .checkered:
            for row in 0..<4 {
                for column in 0..<4 where (row + column).isMultiple(of: 2) {
                    path.addRect(CGRect(x: 0.25 * Double(column), y: 0.25 * Double(row),
                                        width: 0.25, height: 0.25))
                }
            }
        case .lozenge:
            path.addLines([
                CGPoint(x: 0.5, y: 0.08), CGPoint(x: 0.85, y: 0.5),
                CGPoint(x: 0.5, y: 0.92), CGPoint(x: 0.15, y: 0.5)
            ])
            path.closeSubpath()
        case .roundel:
            path.addEllipse(in: CGRect(x: 0.15, y: 0.15, width: 0.7, height: 0.7))
        case .rays:
            let apex = CGPoint(x: 0.5, y: 1.05)
            for index in stride(from: 0, to: 8, by: 2) {
                let left = CGPoint(x: -0.15 + 0.1625 * Double(index), y: -0.05)
                let right = CGPoint(x: -0.15 + 0.1625 * Double(index + 1), y: -0.05)
                path.move(to: apex)
                path.addLine(to: left)
                path.addLine(to: right)
                path.closeSubpath()
            }
        default:
            break
        }
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
