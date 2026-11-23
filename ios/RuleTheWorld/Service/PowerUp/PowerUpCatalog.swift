import Foundation

nonisolated struct PowerUpCatalog: Sendable {
    let all: [PowerUpDefinition]
    private let byId: [Int: PowerUpDefinition]

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "powerups", withExtension: "json")
            ?? bundle.url(forResource: "powerups", withExtension: "json", subdirectory: "Regions")
        self.init(data: url.flatMap { try? Data(contentsOf: $0) })
    }

    init(data: Data?) {
        all = data.flatMap { try? JSONDecoder().decode([PowerUpDefinition].self, from: $0) } ?? []
        byId = Dictionary(all.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    func definition(for id: Int) -> PowerUpDefinition? {
        byId[id]
    }
}
