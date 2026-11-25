import Foundation

nonisolated struct VisitBatchResponse: Decodable {
    let acceptedIds: [String]
    let hexInfos: [HexInfo]
    let rankings: [ProfileSummary.Ranking]

    private enum CodingKeys: String, CodingKey {
        case acceptedIds, hexInfos, rankings
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        acceptedIds = try container.decode([String].self, forKey: .acceptedIds)
        hexInfos = try container.decode([HexInfo].self, forKey: .hexInfos)
        rankings = (try? container.decode([ProfileSummary.Ranking].self, forKey: .rankings)) ?? []
    }
}
