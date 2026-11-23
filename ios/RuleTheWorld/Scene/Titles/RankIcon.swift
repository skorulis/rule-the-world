import SwiftUI

/// A generated badge icon for a rank, matching the power-up icon style.
/// Sources are hand-authored SVGs in ios/Icons, rasterized into the asset catalog.
struct RankIcon: View {
    let name: String
    var size: CGFloat = 44

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
