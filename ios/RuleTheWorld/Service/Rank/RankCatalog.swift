import Foundation

nonisolated struct RankCatalog: Sendable {
    private let definitions: [String: [Int: RankDefinition]]

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "ranks", withExtension: "json")
        self.init(data: url.flatMap { try? Data(contentsOf: $0) })
    }

    init(data: Data?) {
        let groups = data.flatMap {
            try? JSONDecoder().decode([String: [RankDefinition]].self, from: $0)
        } ?? [:]
        definitions = groups.mapValues { ranks in
            Dictionary(ranks.filter { $0.number > 0 }.map { ($0.number, $0) },
                       uniquingKeysWith: { first, _ in first })
        }
    }

    func definition(for number: Int, type: String) -> RankDefinition? {
        definitions[type]?[number]
    }
}
