import MapKit
import Testing
@testable import RuleTheWorld

@MainActor
struct RegionOverlayRendererTests {
    @Test func regionRendererDoesNotReuseHexRenderer() {
        let coordinator = HexMapViewRepresentable.Coordinator(grid: HexGridService())
        let map = MKMapView()
        let grid = HexGridOverlay()
        let hexRenderer = coordinator.mapView(map, rendererFor: grid)
        let coordinates = [
            CLLocationCoordinate2D(latitude: 0, longitude: 0),
            CLLocationCoordinate2D(latitude: 0, longitude: 1),
            CLLocationCoordinate2D(latitude: 1, longitude: 1),
        ]
        let polygon = MKPolygon(coordinates: coordinates, count: coordinates.count)
        let overlay = MKMultiPolygon([polygon])
        let countryRenderer = coordinator.mapView(map, rendererFor: overlay)
        #expect(hexRenderer is HexGridOverlayRenderer)
        #expect(countryRenderer is MKMultiPolygonRenderer)
        #expect(coordinator.mapView(map, rendererFor: grid) === hexRenderer)
    }

    @Test func selectionReplacesOnlyCountryOverlay() throws {
        let coordinator = HexMapViewRepresentable.Coordinator(grid: HexGridService())
        let map = MKMapView()
        let grid = HexGridOverlay()
        map.addOverlay(grid)
        let ring = try MapRegionBoundary.Ring(points: [
            .init(longitude: 0, latitude: 0), .init(longitude: 1, latitude: 0),
            .init(longitude: 1, latitude: 1), .init(longitude: 0, latitude: 0),
        ])
        let boundary = MapRegionBoundary(
            id: "country", name: "Country", kind: .country,
            polygons: [.init(exterior: ring, holes: [])]
        )
        let selection = MapRegionSelection(boundary: boundary, level: .medium)
        coordinator.apply(region: selection, to: map)
        let firstCountry = try #require(map.overlays.first { $0 is MKMultiPolygon })
        coordinator.apply(region: selection, to: map)
        #expect(map.overlays.count == 2)
        #expect(map.overlays.contains { $0 === firstCountry })
        coordinator.apply(region: MapRegionSelection(boundary: boundary, level: .coarse), to: map)
        #expect(map.overlays.count == 2)
        #expect(!map.overlays.contains { $0 === firstCountry })
        coordinator.apply(region: nil, to: map)
        #expect(map.overlays.count == 1)
        #expect(map.overlays.first === grid)
    }
}
