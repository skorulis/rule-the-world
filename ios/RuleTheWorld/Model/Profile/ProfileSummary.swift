import Foundation

nonisolated struct ProfileSummary: Codable, Sendable {
    let visited: Int?
    let owned: Int?
    let regions: [Region]
    var rankings: [Ranking]
    let powerups: [Int: Int]
    let dailyRewardAvailableAt: Date?
    let coins: Int?
    let stipend: Int?
    let stipendAvailableAt: Date?
    let userName: String?
    let userID: String?

    struct Ranking: Codable, Sendable {
        let id: Int64
        let type: String
        let number: Int
        let visited: Int?
        let owned: Int?
    }

    struct User: Codable, Sendable {
        let id: String?
        let name: String?
    }

    struct Region: Codable, Sendable {
        let id: Int64
        let kind: String?
        let visited: Int
        let owned: Int
    }

    private enum CodingKeys: String, CodingKey {
        case visited, owned, regions, rankings, powerups, dailyRewardAvailableAt
        case coins, stipend, stipendAvailableAt, user
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let visited = try? container.decode(Int.self, forKey: .visited)
        let owned = try? container.decode(Int.self, forKey: .owned)
        let validVisited = visited.flatMap { $0 >= 0 ? $0 : nil }
        self.visited = validVisited
        self.owned = owned.flatMap { value in
            guard value >= 0, validVisited.map({ value <= $0 }) ?? true else { return nil }
            return value
        }
        rankings = (try? container.decode([RankingEntry].self, forKey: .rankings))?.compactMap(\.value) ?? []
        regions = (try? container.decode([RegionEntry].self, forKey: .regions))?.compactMap(\.value) ?? []
        let rawPowerups = (try? container.decode([String: Int].self, forKey: .powerups)) ?? [:]
        powerups = rawPowerups.reduce(into: [:]) { result, entry in
            guard let id = Int(entry.key), id > 0, entry.value > 0 else { return }
            result[id] = entry.value
        }
        dailyRewardAvailableAt = (try? container.decode(String.self, forKey: .dailyRewardAvailableAt))
            .flatMap(Self.parseDate)
        coins = (try? container.decode(Int.self, forKey: .coins)).flatMap { $0 >= 0 ? $0 : nil }
        stipend = (try? container.decode(Int.self, forKey: .stipend)).flatMap { $0 >= 0 ? $0 : nil }
        stipendAvailableAt = (try? container.decode(String.self, forKey: .stipendAvailableAt))
            .flatMap(Self.parseDate)
        let user = try? container.decode(User.self, forKey: .user)
        userName = user?.name
        userID = (user?.id).flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(visited, forKey: .visited)
        try container.encodeIfPresent(owned, forKey: .owned)
        try container.encode(regions, forKey: .regions)
        try container.encode(rankings, forKey: .rankings)
        try container.encode(powerups, forKey: .powerups)
        try container.encodeIfPresent(dailyRewardAvailableAt.map(Self.formatDate), forKey: .dailyRewardAvailableAt)
        try container.encodeIfPresent(coins, forKey: .coins)
        try container.encodeIfPresent(stipend, forKey: .stipend)
        try container.encodeIfPresent(stipendAvailableAt.map(Self.formatDate), forKey: .stipendAvailableAt)
        if userID != nil || userName != nil {
            try container.encode(User(id: userID, name: userName), forKey: .user)
        }
    }

    private static func formatDate(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }

    private static func parseDate(_ value: String) -> Date? {
        (try? Date(value, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)))
            ?? (try? Date(value, strategy: Date.ISO8601FormatStyle()))
    }

    private struct RankingEntry: Decodable {
        let value: Ranking?

        init(from decoder: any Decoder) throws {
            let ranking = try? Ranking(from: decoder)
            value = ranking.flatMap {
                guard $0.id > 0, $0.number > 0, ["global", "country", "state", "suburb"].contains($0.type),
                      ($0.visited ?? 0) >= 0, ($0.owned ?? 0) >= 0 else { return nil }
                return $0
            }
        }
    }

    private struct RegionEntry: Decodable {
        let value: Region?

        init(from decoder: any Decoder) throws {
            let region = try? Region(from: decoder)
            value = region.flatMap {
                $0.id > 0 && $0.visited >= 0 && $0.owned >= 0 && $0.owned <= $0.visited ? $0 : nil
            }
        }
    }
}
