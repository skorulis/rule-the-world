import SwiftUI

struct TitleCell: View {
    let item: TitlesViewModel.Item

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = item.icon {
                RankIcon(name: icon, rarity: item.rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text(item.name).font(.title3.bold())
                values
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(statsAccessibilityLabel)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .gameCard(rarity: item.rarity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var values: some View {
        HStack(spacing: 6) {
            if let visited = item.visited {
                Label {
                    Text(visited.formatted())
                } icon: {
                    Image("HexVisited").resizable().scaledToFit().frame(width: 32, height: 32)
                }
            }
            if let owned = item.owned {
                Label {
                    Text(owned.formatted())
                } icon: {
                    Image("HexOwned").resizable().scaledToFit().frame(width: 32, height: 32)
                }
            }
        }

        if let stipend = item.stipend {
            Label {
                Text("+\(stipend.formatted())")
            } icon: {
                Image("Coin").resizable().scaledToFit().frame(width: 32, height: 32)
            }
        }
    }

    private var statsAccessibilityLabel: String {
        var parts: [String] = []
        if let visited = item.visited, let owned = item.owned {
            parts.append("\(visited.formatted()) hexes visited, \(owned.formatted()) hexes owned")
        }
        if let stipend = item.stipend {
            parts.append("daily stipend of \(stipend.formatted()) coins")
        }
        return parts.joined(separator: ", ")
    }
}
