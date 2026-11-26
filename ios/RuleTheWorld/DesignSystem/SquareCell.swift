import SwiftUI

struct SquareCell: View {
    let title: String
    let icon: String
    let value: Int

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title2) private var titleSize: CGFloat = 20

    private let ink = Color(red: 0.18, green: 0.1, blue: 0.06)

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                panel
            } else {
                GeometryReader { geometry in
                    panel
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
                .aspectRatio(1, contentMode: .fit)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(title), \(value.formatted())"))
    }

    private var panel: some View {
        ParchmentPanel(contentInsets: EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4)) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: titleSize, weight: .heavy, design: .rounded))
                    .foregroundStyle(ink)
                Image(icon)
                    .resizable()
                    .scaledToFit()
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: dynamicTypeSize.isAccessibilitySize ? 100 : .infinity
                    )
                    .accessibilityHidden(true)
                LargeValueText(value.formatted())
            }
            .multilineTextAlignment(.center)
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
            .minimumScaleFactor(0.5)
            .frame(maxWidth: .infinity, maxHeight: dynamicTypeSize.isAccessibilitySize ? nil : .infinity)
        }
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 12) {
            SquareCell(title: "Shop", icon: "Shop", value: 1_086)
            SquareCell(title: "Titles", icon: "HexOwned", value: 5)
        }
        HStack(spacing: 12) {
            SquareCell(title: "Shop", icon: "Shop", value: 12_345_678)
            SquareCell(title: "Titles", icon: "HexOwned", value: 0)
        }
    }
    .padding(20)
    .frame(maxHeight: .infinity)
    .background(Color(red: 0.23, green: 0.14, blue: 0.13))
}
