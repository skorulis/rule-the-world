import SwiftUI

/// Renders a banner emblem as layered image assets: a grayscale base tinted
/// with `color` via multiply (preserving shaded artwork), plus an optional
/// fixed-color detail overlay (outlines, gems).
struct EmblemView: View {
    let emblem: BannerEmblem
    let color: BannerColor

    var body: some View {
        ZStack {
            if let base = emblem.baseImageName {
                Image(base)
                    .resizable()
                    .colorMultiply(color.color)
                if let detail = emblem.detailImageName {
                    Image(detail)
                        .resizable()
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    let colors: [BannerColor] = [.gold, .crimson, .ivory]
    VStack(spacing: 16) {
        ForEach(colors, id: \.self) { color in
            HStack(spacing: 12) {
                ForEach(BannerEmblem.allCases.filter { $0 != .none }, id: \.self) { emblem in
                    EmblemView(emblem: emblem, color: color)
                        .frame(width: 48, height: 48)
                }
            }
        }
    }
    .padding()
    .background(.brown)
}
