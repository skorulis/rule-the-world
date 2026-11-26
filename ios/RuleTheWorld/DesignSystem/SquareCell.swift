import SwiftUI

struct SquareCell: View {
    let title: String
    let icon: String
    let value: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            Text(value.formatted())
                .font(.system(.title2, design: .rounded, weight: .semibold))
        }
        .padding(12)
        .aspectRatio(1, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.quaternary, lineWidth: 3)
        }
        .accessibilityElement(children: .combine)
    }
}
