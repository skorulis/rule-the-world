import Foundation

struct TitleNotificationBuilder {
    let catalog: RankCatalog
    let regionNames: RegionNameCatalog

    func notifications(
        from previous: [ProfileSummary.Ranking],
        to current: [ProfileSummary.Ranking]
    ) -> [AppNotification] {
        let previousRanks = Dictionary(
            previous.map { ("\($0.type):\($0.id)", $0.number) },
            uniquingKeysWith: min
        )
        var seen: Set<String> = []
        return current.compactMap { ranking in
            let key = "\(ranking.type):\(ranking.id)"
            guard ranking.id > 0, ranking.number > 0,
                  ["global", "country", "state", "suburb"].contains(ranking.type),
                  seen.insert(key).inserted,
                  previousRanks[key].map({ ranking.number < $0 }) ?? true else { return nil }
            let definition = catalog.definition(for: ranking.number, type: ranking.type)
            let name = definition?.name ?? "Title #\(ranking.number)"
            let region = ranking.type == "global" ? "World" : regionNames.name(for: ranking.id) ?? "Region #\(ranking.id)"
            return AppNotification(
                title: "New title!",
                message: "You have gained the \(name) title in \(region)",
                icon: definition?.icon,
                rarity: definition?.rarity
            )
        }
    }
}
