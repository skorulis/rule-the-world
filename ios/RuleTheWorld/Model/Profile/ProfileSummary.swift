import Foundation

nonisolated struct ProfileSummary: Decodable, Sendable {
    let visited: Int?
    let owned: Int?
    let regions: [Region]
    let rankings: [Ranking]
    let powerups: [Int: Int]
    let dailyRewardAvailableAt: Date?

    struct Ranking: Decodable, Sendable {
        let id: Int64
        let type: String
        let number: Int
    }

    struct Region: Decodable, Sendable {
        let id: Int64
        let kind: String?
        let visited: Int
        let owned: Int
    }

    private enum CodingKeys: String, CodingKey {
        case visited, owned, regions, rankings, powerups, dailyRewardAvailableAt
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
                $0.id > 0 && $0.number > 0 && ["country", "state", "suburb"].contains($0.type) ? $0 : nil
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
