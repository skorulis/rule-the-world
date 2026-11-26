import SwiftUI

struct GameSymbolStyle {
    var face: [Color]
    var outline: Color
    var extrusion: Color
    var highlight: Color
    var outlineWidth: CGFloat = 0.035
    var depth: CGFloat = 0.06

    static let antiqueGold = GameSymbolStyle(
        face: [
            Color(red: 1, green: 0.94, blue: 0.68),
            Color(red: 0.9, green: 0.65, blue: 0.28),
            Color(red: 0.65, green: 0.37, blue: 0.13)
        ],
        outline: Color(red: 0.26, green: 0.14, blue: 0.08),
        extrusion: Color(red: 0.43, green: 0.25, blue: 0.12),
        highlight: Color(red: 1, green: 0.97, blue: 0.8)
    )
}

struct GameSymbol: View {
    let systemName: String
    let style: GameSymbolStyle

    init(_ systemName: String, style: GameSymbolStyle = .antiqueGold) {
        self.systemName = systemName
        self.style = style
    }

    var body: some View {
        GeometryReader { geometry in
            let unit = min(geometry.size.width, geometry.size.height)
            let outline = unit * style.outlineWidth
            let depth = unit * style.depth

            ZStack {
                silhouette
                    .foregroundStyle(style.outline)
                    .offset(y: depth)
                    .shadow(color: style.outline.opacity(0.3), radius: unit * 0.025, y: unit * 0.025)
                    .accessibilityHidden(true)

                ForEach(0..<8) { index in
                    let angle = Double(index) * .pi / 4
                    silhouette
                        .foregroundStyle(style.outline)
                        .offset(x: cos(angle) * outline, y: sin(angle) * outline + depth)
                        .accessibilityHidden(true)
                    silhouette
                        .foregroundStyle(style.outline)
                        .offset(x: cos(angle) * outline, y: sin(angle) * outline)
                        .accessibilityHidden(true)
                }

                silhouette
                    .foregroundStyle(style.extrusion)
                    .offset(y: depth)
                    .accessibilityHidden(true)

                silhouette
                    .foregroundStyle(LinearGradient(colors: style.face, startPoint: .top, endPoint: .bottom))
                    .overlay {
                        style.highlight
                            .mask {
                                ZStack {
                                    silhouette.foregroundStyle(.white)
                                    silhouette
                                        .foregroundStyle(.white)
                                        .offset(y: unit * 0.025)
                                        .blendMode(.destinationOut)
                                }
                                .compositingGroup()
                            }
                            .accessibilityHidden(true)
                    }
            }
            .padding(unit * 0.1)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var silhouette: some View {
        Image(systemName: systemName)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.monochrome)
            .fontWeight(.semibold)
    }
}

#Preview {
    ParchmentPanel {
        HStack(spacing: 20) {
            ForEach(["envelope.fill", "key.fill", "person.fill", "shield.fill"], id: \.self) { name in
                GameSymbol(name)
                    .frame(width: 36, height: 36)
            }
        }
    }
    .padding(24)
}
