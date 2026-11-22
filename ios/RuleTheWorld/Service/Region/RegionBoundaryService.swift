import Foundation

nonisolated protocol RegionBoundaryProviding: Sendable {
    func selection(
        latitude: Double,
        longitude: Double,
        level: RegionOverlayPolicy.Level
    ) async throws -> MapRegionSelection?
}

actor RegionBoundaryService: RegionBoundaryProviding {
    private let urls: [RegionOverlayPolicy.Level: URL]
    private var loading: Task<RegionBoundaryCatalog, Error>?

    init(bundle: Bundle = .main) {
        urls = Dictionary(uniqueKeysWithValues: RegionOverlayPolicy.Level.allCases.compactMap { level in
            let name = switch level {
            case .state: "states-coarse"
            case .suburb: "suburbs-medium"
            default: "countries-\(level.rawValue)"
            }
            let url = bundle.url(forResource: name, withExtension: "pbf")
                ?? bundle.url(forResource: name, withExtension: "pbf", subdirectory: "Regions")
            return url.map { (level, $0) }
        })
    }

    func selection(
        latitude: Double,
        longitude: Double,
        level: RegionOverlayPolicy.Level
    ) async throws -> MapRegionSelection? {
        try Task.checkCancellation()
        if loading == nil {
            let urls = urls
            loading = Task.detached(priority: .utility) {
                let required = Set(RegionOverlayPolicy.Level.allCases).subtracting(RegionBoundaryCatalog.optionalLevels)
                guard Set(urls.keys).isSuperset(of: required) else {
                    throw RegionBoundaryError.missingResource
                }
                let data = try urls.mapValues { try Data(contentsOf: $0) }
                return try RegionBoundaryCatalog(data: data)
            }
        }
        guard let loading else { return nil }
        let catalog = try await loading.value
        try Task.checkCancellation()
        return catalog.selection(latitude: latitude, longitude: longitude, level: level)
    }
}

nonisolated struct RegionBoundaryCatalog: Sendable {
    static let optionalLevels: Set<RegionOverlayPolicy.Level> = [.suburb]

    let boundaries: [RegionOverlayPolicy.Level: [MapRegionBoundary]]
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
