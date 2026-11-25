import Foundation

nonisolated struct RegionShardIndex: Decodable, Sendable {
    struct Shard: Decodable, Sendable {
        let features: Int
        let bytes: Int
        let sha256: String
    }

    let shardResolution: Int
    let shards: [String: Shard]
    let homes: [String: String]
    let coverage: [String: [String]]
}

nonisolated protocol SuburbShardProviding: Sendable {
    func loadIndex() throws -> RegionShardIndex
    func loadShard(cell: String) throws -> Data
}

nonisolated struct BundledSuburbShardStore: SuburbShardProviding, @unchecked Sendable {
    let bundle: Bundle

    init(bundle: Bundle = .main) {
        self.bundle = bundle
    }

    func loadIndex() throws -> RegionShardIndex {
        try JSONDecoder().decode(
            RegionShardIndex.self,
            from: Data(contentsOf: resource("suburbs-index", ofType: "json", subdirectories: ["Regions", nil]))
        )
    }

    func loadShard(cell: String) throws -> Data {
        try Data(contentsOf: resource(cell, ofType: "pbf", subdirectories: ["Regions/suburbs", "suburbs", nil]))
    }

    private func resource(_ name: String, ofType: String, subdirectories: [String?]) throws -> URL {
        for subdirectory in subdirectories {
            if let url = bundle.url(forResource: name, withExtension: ofType, subdirectory: subdirectory) {
                return url
            }
        }
        throw RegionBoundaryError.missingResource
    }
}
