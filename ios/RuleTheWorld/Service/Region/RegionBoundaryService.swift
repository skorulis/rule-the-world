import Foundation
import SwiftyH3

nonisolated protocol RegionBoundaryProviding: Sendable {
    func selection(
        latitude: Double,
        longitude: Double,
        level: RegionOverlayPolicy.Level
    ) async throws -> MapRegionSelection?
}

actor RegionBoundaryService: RegionBoundaryProviding {
    private static let suburbShardLimit = 16

    private let urls: [RegionOverlayPolicy.Level: URL]
    private let fixtureData: [RegionOverlayPolicy.Level: Data]?
    private let suburbStore: any SuburbShardProviding
    private var loading: Task<RegionBoundaryCatalog, Error>?
    private var suburbIndexTask: Task<RegionShardIndex?, Error>?
    private var suburbShardTasks: [String: Task<[MapRegionBoundary], Error>] = [:]
    private var suburbShards: [String: [MapRegionBoundary]] = [:]
    private var suburbShardOrder: [String] = []

    init(bundle: Bundle = .main) {
        fixtureData = nil
        suburbStore = BundledSuburbShardStore(bundle: bundle)
        urls = Dictionary(uniqueKeysWithValues: RegionOverlayPolicy.Level.allCases.compactMap { level in
            guard level != .suburb else { return nil }
            let name = switch level {
            case .state: "states-coarse"
            default: "countries-\(level.rawValue)"
            }
            let url = bundle.url(forResource: name, withExtension: "pbf")
                ?? bundle.url(forResource: name, withExtension: "pbf", subdirectory: "Regions")
            return url.map { (level, $0) }
        })
    }

    init(data: [RegionOverlayPolicy.Level: Data], suburbStore: any SuburbShardProviding) {
        fixtureData = data
        self.suburbStore = suburbStore
        urls = [:]
    }

    func selection(
        latitude: Double,
        longitude: Double,
        level: RegionOverlayPolicy.Level
    ) async throws -> MapRegionSelection? {
        try Task.checkCancellation()
        if level == .suburb {
            return try await suburbSelection(latitude: latitude, longitude: longitude)
        }
        let catalog = try await catalog()
        try Task.checkCancellation()
        return catalog.selection(latitude: latitude, longitude: longitude, level: level)
    }

    private func catalog() async throws -> RegionBoundaryCatalog {
        if loading == nil {
            let urls = urls
            let fixtureData = fixtureData
            loading = Task.detached(priority: .utility) {
                let data: [RegionOverlayPolicy.Level: Data]
                if let fixtureData {
                    data = fixtureData
                } else {
                    let required = Set(RegionOverlayPolicy.Level.allCases)
                        .subtracting(RegionBoundaryCatalog.optionalLevels)
                    guard Set(urls.keys).isSuperset(of: required) else {
                        throw RegionBoundaryError.missingResource
                    }
                    data = try urls.mapValues { try Data(contentsOf: $0) }
                }
                return try RegionBoundaryCatalog(data: data)
            }
        }
        guard let loading else { throw RegionBoundaryError.missingResource }
        return try await loading.value
    }

    private func suburbIndex() async throws -> RegionShardIndex? {
        if suburbIndexTask == nil {
            let store = suburbStore
            suburbIndexTask = Task.detached(priority: .utility) {
                do {
                    return try store.loadIndex()
                } catch RegionBoundaryError.missingResource {
                    return nil
                }
            }
        }
        return try await suburbIndexTask?.value
    }

    private func suburbSelection(latitude: Double, longitude: Double) async throws -> MapRegionSelection? {
        guard latitude.isFinite, (-90...90).contains(latitude), longitude.isFinite,
              let index = try await suburbIndex() else {
            return nil
        }
        let wrapped = ((longitude + 180).truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360) - 180
        guard let resolution = H3Cell.Resolution(rawValue: Int32(index.shardResolution)),
              let h3cell = try? H3LatLng(latitudeDegs: latitude, longitudeDegs: wrapped).cell(at: resolution),
              let covered = index.coverage[String(h3cell.id, radix: 16)], !covered.isEmpty else {
            return nil
        }
        let coveredIds = Set(covered)
        var candidates: [MapRegionBoundary] = []
        for home in Set(covered.compactMap { index.homes[$0] }) {
            for region in try await shardRegions(home) where coveredIds.contains(region.id) {
                candidates.append(region)
            }
        }
        guard let suburb = candidates.sorted(by: { $0.id < $1.id })
            .first(where: { $0.kind == .suburb && $0.contains(latitude: latitude, longitude: longitude) }),
              let parent = suburb.parent else {
            return nil
        }
        guard try await catalog().stateIds.contains(parent) else { return nil }
        return MapRegionSelection(boundary: suburb, level: .suburb)
    }

    private func shardRegions(_ cell: String) async throws -> [MapRegionBoundary] {
        if let cached = suburbShards[cell] { return cached }
        if let task = suburbShardTasks[cell] { return try await task.value }
        let store = suburbStore
        let task = Task.detached(priority: .utility) {
            try GeobufRegionDecoder.decode(store.loadShard(cell: cell))
        }
        suburbShardTasks[cell] = task
        do {
            let regions = try await task.value
            suburbShardTasks[cell] = nil
            if suburbShardOrder.count >= Self.suburbShardLimit, let oldest = suburbShardOrder.first {
                suburbShardOrder.removeFirst()
                suburbShards[oldest] = nil
            }
            suburbShardOrder.append(cell)
            suburbShards[cell] = regions
            return regions
        } catch {
            suburbShardTasks[cell] = nil
            throw error
        }
    }
}

nonisolated struct RegionBoundaryCatalog: Sendable {
    static let optionalLevels: Set<RegionOverlayPolicy.Level> = [.suburb]

    let boundaries: [RegionOverlayPolicy.Level: [MapRegionBoundary]]
    let stateIds: Set<String>
    private let displayBoundaries: [RegionOverlayPolicy.Level: [String: MapRegionBoundary]]
    private let statesByParent: [String: [MapRegionBoundary]]

    init(data: [RegionOverlayPolicy.Level: Data]) throws {
        var decoded: [RegionOverlayPolicy.Level: [MapRegionBoundary]] = [:]
        for level in RegionOverlayPolicy.Level.allCases {
            guard let contents = data[level] else {
                if level == .state || Self.optionalLevels.contains(level) {
                    decoded[level] = []
                    continue
                }
                throw RegionBoundaryError.missingResource
            }
            let regions = try GeobufRegionDecoder.decode(contents).sorted { $0.id < $1.id }
            guard Set(regions.map(\.id)).count == regions.count else {
                throw RegionBoundaryError.invalidCollection
            }
            decoded[level] = regions
        }
        guard Set(decoded[.medium, default: []].map(\.id)) == Set(decoded[.coarse, default: []].map(\.id)) else {
            throw RegionBoundaryError.invalidCollection
        }
        boundaries = decoded
        displayBoundaries = decoded.mapValues { Dictionary(uniqueKeysWithValues: $0.map { ($0.id, $0) }) }
        var grouped: [String: [MapRegionBoundary]] = [:]
        for state in decoded[.state, default: []] {
            guard let parent = state.parent else { throw RegionBoundaryError.invalidCollection }
            grouped[parent, default: []].append(state)
        }
        statesByParent = grouped
        stateIds = Set(decoded[.state, default: []].map(\.id))
        let states = Dictionary(uniqueKeysWithValues: decoded[.state, default: []].map { ($0.id, $0) })
        let countries = Set(decoded[.medium, default: []].filter { $0.kind == .country }.map(\.id))
        for suburb in decoded[.suburb, default: []] {
            guard suburb.kind == .suburb, let parent = suburb.parent,
                  let state = states[parent], state.kind == .state,
                  let country = state.parent, countries.contains(country) else {
                throw RegionBoundaryError.invalidCollection
            }
        }
    }

    func selection(latitude: Double, longitude: Double, level: RegionOverlayPolicy.Level) -> MapRegionSelection? {
        let containsPoint = { (boundary: MapRegionBoundary) in
            boundary.contains(latitude: latitude, longitude: longitude)
        }
        if level == .suburb {
            guard let suburb = boundaries[.suburb]?.first(where: containsPoint) else { return nil }
            return MapRegionSelection(boundary: suburb, level: level)
        }
        guard let region = boundaries[.medium]?.first(where: containsPoint) else { return nil }
        if level == .state {
            guard let state = statesByParent[region.id]?.first(where: containsPoint) else { return nil }
            return MapRegionSelection(boundary: state, level: level)
        }
        guard let display = displayBoundaries[level]?[region.id] else { return nil }
        return MapRegionSelection(boundary: display, level: level)
    }
}
