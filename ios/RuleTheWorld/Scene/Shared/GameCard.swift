import SwiftUI

/// Rounded "game card" chrome for list rows: tinted fill, accent border and
/// a soft glow for prominent (epic+) cards — matching PowerUpCard's style.
struct GameCardStyle: ViewModifier {
    let accent: Color
    var prominent = false

    func body(content: Content) -> some View {
        content
            .padding(12)
            .background {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(prominent ? 0.14 : 0.07))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(border, lineWidth: prominent ? 1.5 : 1)
            }
            .shadow(color: prominent ? accent.opacity(0.45) : .clear, radius: 8)
    }

    private var border: AnyShapeStyle {
        if prominent {
            AnyShapeStyle(LinearGradient(
                colors: [accent, accent.opacity(0.4)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        } else {
            AnyShapeStyle(accent.opacity(0.5))
        }
    }
}

extension View {
    /// Wraps the view in game-card chrome tinted by `accent`.
    func gameCard(accent: Color, prominent: Bool = false) -> some View {
        modifier(GameCardStyle(accent: accent, prominent: prominent))
    }

    /// Wraps the view in game-card chrome using the rarity's color; epic and
    /// above get the gradient border and glow like `PowerUpCard`.
    func gameCard(rarity: Rarity?, fallback: Color = .secondary) -> some View {
        gameCard(
            accent: rarity?.color ?? fallback,
            prominent: rarity.map { $0 >= .epic } ?? false
        )
    }
}
