import CoreLocation
import MapKit
import Testing
@testable import RuleTheWorld

struct HexGridServiceTests {
    let grid = HexGridService()

    @Test func coordinateToCellRoundTrip() {
        let coordinate = CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19)
        let cell = grid.cell(containing: coordinate, resolution: 9)

        #expect(cell.rawValue != 0)

        let boundary = grid.boundary(of: cell)
        #expect(boundary.count == 6 || boundary.count == 5)

        let minLat = boundary.map(\.latitude).min()!
        let maxLat = boundary.map(\.latitude).max()!
        let minLon = boundary.map(\.longitude).min()!
        let maxLon = boundary.map(\.longitude).max()!
        #expect(coordinate.latitude >= minLat && coordinate.latitude <= maxLat)
        #expect(coordinate.longitude >= minLon && coordinate.longitude <= maxLon)
    }

    @Test func cellsInRegionReturnsPlausibleCount() {
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
        )
        let cells = grid.cells(in: region, resolution: 9)
        #expect(cells.count > 10)
        #expect(cells.count < 200)
        #expect(Set(cells).count == cells.count)
    }

    @Test func parentAndChildrenRoundTrip() {
        let coordinate = CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19)
        let cell = grid.cell(containing: coordinate, resolution: 9)
        let parent = grid.parent(of: cell, at: 7)
        #expect(parent != nil)

        let children = grid.children(of: parent!, at: 9)
        #expect(children.contains(cell))
    }
}
