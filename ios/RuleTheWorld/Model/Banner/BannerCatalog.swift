import Foundation

nonisolated enum BannerPattern: String, CaseIterable, Sendable {
    case solid, horizontalSplit, verticalSplit, diagonalBand, cross, chevron

    var title: String {
        switch self {
        case .solid: "Solid"
        case .horizontalSplit: "Horizontal split"
        case .verticalSplit: "Vertical split"
        case .diagonalBand: "Diagonal band"
        case .cross: "Cross"
        case .chevron: "Chevron"
        }
    }
}

nonisolated enum BannerEmblem: String, CaseIterable, Sendable {
    case none, crown, compass, shield, sword, star

    var title: String { rawValue.capitalized }

    /// Grayscale luminance asset, tinted at render time with `colorMultiply`.
    var baseImageName: String? {
        switch self {
        case .none: nil
        case .crown: "EmblemCrown"
        case .compass: "EmblemCompass"
        case .shield: "EmblemShield"
        case .sword: "EmblemSword"
        case .star: "EmblemStar"
        }
    }

    /// Fixed-color overlay (outlines, gems) drawn untinted on top of the base.
    var detailImageName: String? {
        baseImageName.map { $0 + "Detail" }
    }
}

nonisolated enum BannerColor: String, CaseIterable, Sendable {
    case purple, navy, gold, crimson, forest, orange, ivory, charcoal

    var title: String { rawValue.capitalized }

    struct RGB: Sendable {
        let red: Double
        let green: Double
        let blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }
    }

    var rgb: RGB {
        switch self {
        case .purple: RGB(0.43, 0.20, 0.60)
        case .navy: RGB(0.16, 0.22, 0.43)
        case .gold: RGB(0.98, 0.73, 0.18)
        case .crimson: RGB(0.73, 0.12, 0.17)
        case .forest: RGB(0.18, 0.49, 0.28)
        case .orange: RGB(0.94, 0.39, 0.08)
        case .ivory: RGB(0.98, 0.92, 0.73)
        case .charcoal: RGB(0.17, 0.18, 0.22)
        }
    }
}
