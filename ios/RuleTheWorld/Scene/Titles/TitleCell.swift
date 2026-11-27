import SwiftUI

struct TitleCell: View {
    let item: TitlesViewModel.Item

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let icon = item.icon {
                RankIcon(name: icon, rarity: item.rarity, size: 64)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(item.name).font(.title3.bold())
                values
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(statsAccessibilityLabel)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote).foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .parchmentCell(rarity: item.rarity)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var values: some View {
        HStack(spacing: 10) {
            if let visited = item.visited {
                HexNumber(visited, color: .hexVisited, size: .small)
            }
            if let owned = item.owned {
                HexNumber(owned, color: .hexOwned, size: .small)
            }
            Spacer(minLength: 0)
            if let stipend = item.stipend {
                IconText(icon: "Coin", text: "+\(stipend.formatted())")
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

#Preview {
    List {
        ForEach([
            TitlesViewModel.Item(
                id: "suburb:1", number: 3, type: "suburb", ranks: [],
                name: "Sydney Councillor", icon: "RankCouncillor", rarity: .epic,
                regionName: "Sydney", detail: nil, visited: 23, owned: 17, stipend: 9
            ),
            TitlesViewModel.Item(
                id: "country:au", number: 7, type: "country", ranks: [],
                name: "Australian Yeoman", icon: "RankYeoman", rarity: .common,
                regionName: "Australia", detail: nil, visited: 23, owned: 17, stipend: 15
            ),
            TitlesViewModel.Item(
                id: "global:1", number: 12, type: "global", ranks: [],
                name: "American Crofter", icon: "RankCrofter", rarity: nil,
                regionName: "World", detail: nil, visited: 6, owned: 6, stipend: nil
            )
        ]) { item in
            TitleCell(item: item)
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10))
        }
    }
    .listStyle(.insetGrouped)
    .scrollContentBackground(.hidden)
    .background(Color(red: 0.2, green: 0.12, blue: 0.13))
    .environment(\.colorScheme, .light)
}
