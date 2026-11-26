import SwiftUI

struct ProfileStatsCard: View {
    let visited: Int?
    let owned: Int?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        TitledParchmentPanel("Stats") {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    visitedStat
                    if visited != nil && owned != nil {
                        Rectangle()
                            .fill(.brown.opacity(0.3))
                            .frame(width: 1, height: 64)
                            .accessibilityHidden(true)
                    }
                    ownedStat
                }
                .fixedSize(horizontal: true, vertical: false)

                VStack(alignment: .leading, spacing: 16) {
                    visitedStat
                    if visited != nil && owned != nil {
                        Rectangle()
                            .fill(.brown.opacity(0.3))
                            .frame(height: 1)
                            .accessibilityHidden(true)
                    }
                    ownedStat
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var visitedStat: some View {
        stat(visited, title: "Hexes\nVisited", color: Color(red: 0.2, green: 0.57, blue: 0.79))
    }

    private var ownedStat: some View {
        stat(owned, title: "Hexes\nOwned", color: Color(red: 0.84, green: 0.27, blue: 0.25))
    }

    @ViewBuilder
    private func stat(_ value: Int?, title: LocalizedStringKey, color: Color) -> some View {
        if let value {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 8))

            layout {
                HexNumber(value, color: color)
                Text(title)
                    .font(.system(.headline, design: .rounded, weight: .heavy))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            ProfileStatsCard(visited: 30, owned: 24)
            ProfileStatsCard(visited: 0, owned: 0)
            ProfileStatsCard(visited: 12, owned: nil)
            ProfileStatsCard(visited: 1_234_567, owned: 9_876)
        }
        .padding(20)
    }
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}

#Preview("Large text") {
    ScrollView {
        ProfileStatsCard(visited: 30, owned: 24)
            .padding(20)
    }
    .environment(\.dynamicTypeSize, .accessibility1)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
}
