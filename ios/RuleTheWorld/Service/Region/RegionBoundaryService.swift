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
            let name = level == .state ? "states-coarse" : "countries-\(level.rawValue)"
            let url = bundle.url(forResource: name, withExtension: "geojson")
                ?? bundle.url(forResource: name, withExtension: "geojson", subdirectory: "Regions")
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
                guard urls.count == RegionOverlayPolicy.Level.allCases.count else {
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
    let boundaries: [RegionOverlayPolicy.Level: [MapRegionBoundary]]
    private let displayBoundaries: [RegionOverlayPolicy.Level: [String: MapRegionBoundary]]
    private let statesByParent: [String: [MapRegionBoundary]]

    init(data: [RegionOverlayPolicy.Level: Data]) throws {
        var decoded: [RegionOverlayPolicy.Level: [MapRegionBoundary]] = [:]
        for level in RegionOverlayPolicy.Level.allCases {
            guard let contents = data[level] else {
                if level == .state {
                    decoded[level] = []
                    continue
                }
                throw RegionBoundaryError.missingResource
            }
            let collection = try JSONDecoder().decode(Collection.self, from: contents)
            guard collection.type == "FeatureCollection", !collection.features.isEmpty else {
                throw RegionBoundaryError.invalidCollection
            }
            let regions = try collection.features.map { try $0.boundary() }.sorted { $0.id < $1.id }
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
    }

    func selection(latitude: Double, longitude: Double, level: RegionOverlayPolicy.Level) -> MapRegionSelection? {
        let containsPoint = { (boundary: MapRegionBoundary) in
            boundary.contains(latitude: latitude, longitude: longitude)
        }
        guard let region = boundaries[.medium]?.first(where: containsPoint) else { return nil }
        if level == .state {
            guard let state = statesByParent[region.id]?.first(where: containsPoint) else { return nil }
            return MapRegionSelection(boundary: state, level: level)
        }
        guard let display = displayBoundaries[level]?[region.id] else { return nil }
        return MapRegionSelection(boundary: display, level: level)
    }

    private struct Collection: Decodable {
        let type: String
        let features: [Feature]
    }

    private struct Properties: Decodable {
        let id: String
        let name: String
        let kind: String
        let parent: String?
    }

    private struct Feature: Decodable {
        let type: String
        let properties: Properties
        let geometry: Geometry

        func boundary() throws -> MapRegionBoundary {
            guard type == "Feature", !properties.id.isEmpty, !geometry.polygons.isEmpty,
                  let kind = RegionType(name: properties.kind), kind != .none else {
                throw RegionBoundaryError.invalidCollection
            }
            let polygons = try geometry.polygons.map { rings in
                guard let exterior = rings.first else { throw RegionBoundaryError.invalidGeometry }
                return try MapRegionBoundary.Polygon(
                    exterior: MapRegionBoundary.Ring(points: exterior),
                    holes: rings.dropFirst().map { try MapRegionBoundary.Ring(points: $0) }
                )
            }
            return MapRegionBoundary(
                id: properties.id, name: properties.name, kind: kind, parent: properties.parent, polygons: polygons
            )
        }
    }

    private enum GeometryKeys: CodingKey {
        case type, coordinates
    }

    private struct Geometry: Decodable {
        let polygons: [[[MapRegionBoundary.Point]]]

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: GeometryKeys.self)
            switch try container.decode(String.self, forKey: .type) {
            case "Polygon":
                polygons = [try container.decode([[MapRegionBoundary.Point]].self, forKey: .coordinates)]
            case "MultiPolygon":
                polygons = try container.decode([[[MapRegionBoundary.Point]]].self, forKey: .coordinates)
            default:
                throw RegionBoundaryError.invalidGeometry
            }
        }
    }
}
