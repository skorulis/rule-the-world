import Foundation

nonisolated struct RegionNameCatalog: Sendable {
    private let names: [String: String]
    private let demonyms: [String: String]

    init(bundle: Bundle = .main) {
        self.init(
            data: Self.resourceData("region-names", in: bundle),
            demonymsData: Self.resourceData("country-demonyms", in: bundle)
        )
    }

    init(data: Data?, demonymsData: Data? = nil) {
        names = Self.decode(data)
        demonyms = Self.decode(demonymsData)
    }

    func name(for id: Int64) -> String? {
        Self.value(in: names, for: id)
    }

    /// The adjectival form of a country's name ("Australia" -> "Australian"), for combining into title names.
    func demonym(for id: Int64) -> String? {
        Self.value(in: demonyms, for: id)
    }

    private static func resourceData(_ name: String, in bundle: Bundle) -> Data? {
        let url = bundle.url(forResource: name, withExtension: "json")
            ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Regions")
        return url.flatMap { try? Data(contentsOf: $0) }
    }

    private static func decode(_ data: Data?) -> [String: String] {
        data.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) } ?? [:]
    }

    private static func value(in table: [String: String], for id: Int64) -> String? {
        guard id > 0, let value = table[String(id)]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }
}
