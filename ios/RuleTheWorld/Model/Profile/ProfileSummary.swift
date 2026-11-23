import Foundation

nonisolated struct ProfileSummary: Decodable, Sendable {
    let visited: Int?
    let owned: Int?
    let regions: [Region]
    let powerups: [Int: Int]
    let dailyRewardAvailableAt: Date?

    struct Region: Decodable, Sendable {
        let id: Int64
        let kind: String?
        let visited: Int
        let owned: Int
    }

    private enum CodingKeys: String, CodingKey {
        case visited, owned, regions, powerups, dailyRewardAvailableAt
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
