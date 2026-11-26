import SwiftUI

struct IconText: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            Image(icon)
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
