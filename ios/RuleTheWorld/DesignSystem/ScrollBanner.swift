import SwiftUI

/// Rolled-scroll banner chrome: the rolled ends stay fixed while the flat
/// middle paper stretches horizontally to fit the content.
struct ScrollBanner<Content: View>: View {
    private let contentInsets: EdgeInsets
    private let minHeight: CGFloat
    private let content: Content

    init(
        contentInsets: EdgeInsets = EdgeInsets(top: 0, leading: 52, bottom: 0, trailing: 42),
        minHeight: CGFloat = 76,
        @ViewBuilder content: () -> Content
    ) {
        self.contentInsets = contentInsets
        self.minHeight = minHeight
        self.content = content()
    }

    var body: some View {
        content
            .padding(contentInsets)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .background {
                Image("ScrollBanner")
                    .resizable(
                        capInsets: EdgeInsets(top: 0, leading: 48, bottom: 0, trailing: 48),
                        resizingMode: .stretch
                    )
                    .accessibilityHidden(true)
            }
    }
}

#Preview {
    VStack(spacing: 24) {
        ScrollBanner {
            HStack(spacing: 10) {
                Image("Coin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text("Coins")
                Spacer()
                Text(1_158.formatted())
                    .monospacedDigit()
            }
            .font(.system(.title3, design: .rounded, weight: .heavy))
            .foregroundStyle(Color(red: 0.25, green: 0.12, blue: 0.04))
        }
        ScrollBanner {
            Text("Short")
        }
    }
    .padding(24)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}
