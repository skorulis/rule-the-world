import Foundation

nonisolated struct RegionNameCatalog: Sendable {
    private let names: [String: String]

    init(bundle: Bundle = .main) {
        let url = bundle.url(forResource: "region-names", withExtension: "json")
            ?? bundle.url(forResource: "region-names", withExtension: "json", subdirectory: "Regions")
        self.init(data: url.flatMap { try? Data(contentsOf: $0) })
    }

    init(data: Data?) {
        names = data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    func name(for id: Int64) -> String? {
        guard id > 0, let name = names[String(id)]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !name.isEmpty else { return nil }
        return name
    }
}
