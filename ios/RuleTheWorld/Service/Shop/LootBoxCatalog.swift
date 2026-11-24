import Foundation

nonisolated struct LootBoxCatalog: Sendable {
    let all: [LootBoxDefinition]
    private let byId: [Int: LootBoxDefinition]

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "lootboxes", withExtension: "json")
        self.init(data: url.flatMap { try? Data(contentsOf: $0) })
    }

    init(data: Data?) {
        all = data.flatMap { try? JSONDecoder().decode([LootBoxDefinition].self, from: $0) } ?? []
        byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func definition(for id: Int) -> LootBoxDefinition? {
        byId[id]
    }
}
