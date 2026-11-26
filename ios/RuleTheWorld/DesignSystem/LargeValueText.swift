import SwiftUI

struct LargeValueText: View {
    let text: String
    let color: Color
    let size: CGFloat

    @ScaledMetric(relativeTo: .largeTitle) private var scale: CGFloat = 1

    init(_ text: String, color: Color = Color(red: 1, green: 0.88, blue: 0.48), size: CGFloat = 32) {
        self.text = text
        self.color = color
        self.size = size
    }

    private var fontSize: CGFloat { size * scale }

    var body: some View {
        Text(text)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .foregroundStyle(color)
            .background {
                ZStack {
                    ForEach(0..<8) { step in
                        Text(text)
                            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 0.18, green: 0.1, blue: 0.06))
                            .offset(
                                x: cos(Double(step) * .pi / 4) * 1.5,
                                y: sin(Double(step) * .pi / 4) * 1.5
                            )
                    }
                }
                .accessibilityHidden(true)
            }
    }
}

#Preview {
    VStack(spacing: 16) {
        LargeValueText(1_086.formatted())
        LargeValueText(0.formatted())
        LargeValueText(12_345_678.formatted())
    }
    .padding()
    .background(LinearGradient(colors: ParchmentPalette.colors, startPoint: .top, endPoint: .bottom))
}
