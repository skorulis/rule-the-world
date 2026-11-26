import SwiftUI

struct TitledParchmentPanel<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content
    private let ink = Color(red: 0.18, green: 0.1, blue: 0.06)

    init(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(.title2, design: .rounded, weight: .heavy))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 24)
                .padding(.top, 4)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .foregroundStyle(ink)
        .padding(16)
        .frame(maxWidth: .infinity)
        .background {
            TitledParchmentShape()
                .fill(LinearGradient(colors: ParchmentPalette.colors, startPoint: .top, endPoint: .bottom))
                .overlay {
                    RadialGradient(
                        colors: [Color(red: 1, green: 0.95, blue: 0.78).opacity(0.7), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                    .clipShape(TitledParchmentShape())
                }
                .overlay {
                    TitledParchmentShape()
                        .stroke(Color.brown.opacity(0.25), style: StrokeStyle(lineWidth: 7, lineJoin: .round))
                        .clipShape(TitledParchmentShape())
                }
                .overlay {
                    TitledParchmentShape()
                        .stroke(ink, style: StrokeStyle(lineWidth: 2.5, lineJoin: .round))
                }
                .compositingGroup()
                .shadow(color: .black.opacity(0.3), radius: 3, y: 4)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

private struct TitledParchmentShape: Shape {
    func path(in rect: CGRect) -> Path {
        let paper = rect.insetBy(dx: 3, dy: 3)
        let shoulder = min(12, paper.height * 0.1)
        let notch: CGFloat = 4
        return Path { path in
            path.addLines([
                CGPoint(x: paper.minX, y: paper.minY + shoulder),
                CGPoint(x: paper.minX + paper.width * 0.2, y: paper.minY + shoulder),
                CGPoint(x: paper.minX + paper.width * 0.2 + 8, y: paper.minY),
                CGPoint(x: paper.maxX - paper.width * 0.2 - 8, y: paper.minY),
                CGPoint(x: paper.maxX - paper.width * 0.2, y: paper.minY + shoulder),
                CGPoint(x: paper.maxX, y: paper.minY + shoulder - 1),
                CGPoint(x: paper.maxX - 1, y: paper.midY - notch),
                CGPoint(x: paper.maxX - notch, y: paper.midY),
                CGPoint(x: paper.maxX, y: paper.midY + notch),
                CGPoint(x: paper.maxX - 2, y: paper.maxY - notch),
                CGPoint(x: paper.maxX - 10, y: paper.maxY),
                CGPoint(x: paper.midX + notch, y: paper.maxY - 1),
                CGPoint(x: paper.midX, y: paper.maxY - notch),
                CGPoint(x: paper.midX - notch, y: paper.maxY),
                CGPoint(x: paper.minX + 1, y: paper.maxY - 1),
                CGPoint(x: paper.minX + 2, y: paper.midY + notch),
                CGPoint(x: paper.minX + notch, y: paper.midY),
                CGPoint(x: paper.minX, y: paper.midY - notch),
            ])
            path.closeSubpath()
        }
    }
}

#Preview {
    TitledParchmentPanel("Daily rewards") {
        VStack(spacing: 12) {
            Button("Open common box") {}
            Button("Collect daily stipend") {}
        }
        .buttonStyle(GoldButtonStyle(fillsWidth: true))
    }
    .padding(20)
    .frame(maxHeight: .infinity)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}

#Preview("Long title and large text") {
    ScrollView {
        TitledParchmentPanel("Rewards for your next daily adventure") {
            Text("A parchment panel that grows with its title and content.")
        }
        .padding(20)
    }
    .environment(\.dynamicTypeSize, .accessibility1)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}
