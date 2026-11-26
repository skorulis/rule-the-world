import SwiftUI

/// Torn-edge parchment scroll chrome for list rows: the same hand-cut paper
/// silhouette and black border as `TitledParchmentPanel`, without the title
/// shoulder — plus a colored glow behind the paper (typically the rarity color).
struct ParchmentCellStyle: ViewModifier {
    let accent: Color
    var prominent = false

    func body(content: Content) -> some View {
        content
            .padding(EdgeInsets(top: 16, leading: 16, bottom: 18, trailing: 16))
            .background {
                ParchmentCellBackground()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .shadow(color: accent.opacity(prominent ? 0.6 : 0.35), radius: prominent ? 12 : 8)
    }
}

extension View {
    /// Wraps the view in torn-parchment chrome with a glow tinted by `accent`.
    func parchmentCell(accent: Color, prominent: Bool = false) -> some View {
        modifier(ParchmentCellStyle(accent: accent, prominent: prominent))
    }

    /// Wraps the view in torn-parchment chrome using the rarity's color for the
    /// glow; epic and above get a stronger halo.
    func parchmentCell(rarity: Rarity?, fallback: Color = .secondary) -> some View {
        parchmentCell(
            accent: rarity?.color ?? fallback,
            prominent: rarity.map { $0 >= .epic } ?? false
        )
    }
}

private struct ParchmentCellBackground: View {
    private let ink = Color(red: 0.18, green: 0.13, blue: 0.12)
    private let steel = Color(red: 0.52, green: 0.49, blue: 0.46)
    private let steelHighlight = Color(red: 0.78, green: 0.75, blue: 0.67)

    var body: some View {
        ParchmentCellShape()
            .fill(LinearGradient(colors: ParchmentPalette.colors, startPoint: .top, endPoint: .bottom))
            .overlay {
                RadialGradient(
                    colors: [Color(red: 1, green: 0.95, blue: 0.78).opacity(0.7), .clear],
                    center: .center,
                    startRadius: 0,
                    endRadius: 250
                )
                .clipShape(ParchmentCellShape())
            }
            .overlay {
                ParchmentCellShape()
                    .stroke(Color.brown.opacity(0.25), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
                    .clipShape(ParchmentCellShape())
            }
            .overlay {
                ParchmentCellShape()
                    .stroke(.black, style: StrokeStyle(lineWidth: 4, lineJoin: .round))
            }
            .overlay {
                Canvas { context, size in
                    drawRivets(in: context, rect: CGRect(origin: .zero, size: size).insetBy(dx: 11, dy: 11))
                }
            }
            .compositingGroup()
            .shadow(color: .black.opacity(0.3), radius: 3, y: 4)
    }

    private func drawRivets(in context: GraphicsContext, rect: CGRect) {
        let positions = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.minX, y: rect.maxY),
            CGPoint(x: rect.maxX, y: rect.maxY),
        ]
        for position in positions {
            let rivet = Path(ellipseIn: CGRect(x: position.x - 3.5, y: position.y - 3.5, width: 7, height: 7))
            context.fill(rivet, with: .linearGradient(
                Gradient(colors: [steelHighlight, steel, ink]),
                startPoint: CGPoint(x: position.x - 2, y: position.y - 3.5),
                endPoint: CGPoint(x: position.x + 2, y: position.y + 3.5)
            ))
            context.stroke(rivet, with: .color(ink), lineWidth: 1.5)
        }
    }
}

/// Same torn silhouette as `TitledParchmentShape` but with a gently waving top
/// edge instead of the stepped shoulder that holds a title.
private struct ParchmentCellShape: Shape {
    // swiftlint:disable:next function_body_length
    func path(in rect: CGRect) -> Path {
        let paper = rect.insetBy(dx: 5, dy: 5)
        let notch: CGFloat = 4
        let curl = min(5, paper.width * 0.015)
        return Path { path in
            path.move(to: CGPoint(x: paper.minX + 8, y: paper.minY + 2))
            path.addQuadCurve(
                to: CGPoint(x: paper.midX - notch, y: paper.minY),
                control: CGPoint(x: paper.minX + paper.width * 0.3, y: paper.minY - curl * 0.5)
            )
            path.addLine(to: CGPoint(x: paper.midX + notch, y: paper.minY + 1))
            path.addQuadCurve(
                to: CGPoint(x: paper.maxX - 8, y: paper.minY + 2),
                control: CGPoint(x: paper.minX + paper.width * 0.7, y: paper.minY - curl * 0.5)
            )
            path.addQuadCurve(
                to: CGPoint(x: paper.maxX - 1, y: paper.minY + 8),
                control: CGPoint(x: paper.maxX, y: paper.minY)
            )
            path.addQuadCurve(
                to: CGPoint(x: paper.maxX - 1, y: paper.midY - notch),
                control: CGPoint(x: paper.maxX - curl, y: paper.minY + paper.height * 0.3)
            )
            path.addLine(to: CGPoint(x: paper.maxX - notch, y: paper.midY))
            path.addLine(to: CGPoint(x: paper.maxX, y: paper.midY + notch))
            path.addQuadCurve(
                to: CGPoint(x: paper.maxX - 2, y: paper.maxY - 8),
                control: CGPoint(x: paper.maxX - curl, y: paper.minY + paper.height * 0.78)
            )
            path.addQuadCurve(to: CGPoint(x: paper.maxX - 10, y: paper.maxY - 2),
                              control: CGPoint(x: paper.maxX, y: paper.maxY))
            path.addQuadCurve(
                to: CGPoint(x: paper.midX + notch, y: paper.maxY - 1),
                control: CGPoint(x: paper.minX + paper.width * 0.75, y: paper.maxY - curl)
            )
            path.addLine(to: CGPoint(x: paper.midX, y: paper.maxY - notch))
            path.addLine(to: CGPoint(x: paper.midX - notch, y: paper.maxY))
            path.addQuadCurve(
                to: CGPoint(x: paper.minX + 10, y: paper.maxY - 2),
                control: CGPoint(x: paper.minX + paper.width * 0.25, y: paper.maxY - curl)
            )
            path.addQuadCurve(to: CGPoint(x: paper.minX + 1, y: paper.maxY - 9),
                              control: CGPoint(x: paper.minX, y: paper.maxY))
            path.addQuadCurve(
                to: CGPoint(x: paper.minX + 2, y: paper.midY + notch),
                control: CGPoint(x: paper.minX + curl, y: paper.minY + paper.height * 0.75)
            )
            path.addLine(to: CGPoint(x: paper.minX + notch, y: paper.midY))
            path.addLine(to: CGPoint(x: paper.minX, y: paper.midY - notch))
            path.addQuadCurve(
                to: CGPoint(x: paper.minX + 1, y: paper.minY + 8),
                control: CGPoint(x: paper.minX + curl, y: paper.minY + paper.height * 0.3)
            )
            path.addQuadCurve(
                to: CGPoint(x: paper.minX + 8, y: paper.minY + 2),
                control: CGPoint(x: paper.minX, y: paper.minY)
            )
            path.closeSubpath()
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        ForEach(Rarity.allCases, id: \.self) { rarity in
            HStack {
                Text(rarity.displayName).font(.title3.bold())
                Spacer()
                Text("+9")
            }
            .parchmentCell(rarity: rarity)
        }
    }
    .padding(24)
    .frame(maxHeight: .infinity)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
    .environment(\.colorScheme, .light)
}
