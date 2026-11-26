import SwiftUI

struct RegionLeaderCell: View {
    let leader: RegionLeader
    let definition: RankDefinition?
    let rankName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let icon = definition?.icon {
                RankIcon(name: icon, rarity: definition?.rarity)
                    .padding(.top, 2)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(leader.name).font(.headline)
                Text(rankName)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            Label {
                Text(leader.owned.formatted())
            } icon: {
                Image("HexOwned").resizable().scaledToFit().frame(width: 32, height: 32)
            }
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 2)
        }
        .gameCard(rarity: definition?.rarity)
    }
}
