import MapKit
import Testing
@testable import RuleTheWorld

@MainActor
struct PowerUpWindowTests {
    private func makeMap() -> MKMapView {
        let map = MKMapView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        map.setRegion(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ),
            animated: false
        )
        return map
    }

    @Test func targetsAreFullyInsideUnobscuredMap() throws {
        let map = makeMap()
        let grid = HexGridService()
        let coordinator = HexMapViewRepresentable.Coordinator(grid: grid)
        coordinator.powerUpTopInset = 76
        coordinator.powerUpBottomInset = 220
        let cells = try #require(coordinator.powerUpWindow(in: map))
        #expect(!cells.isEmpty)
        let rect = CGRect(x: 0, y: 76, width: 390, height: 548)
        for cell in cells {
            #expect(grid.boundary(of: cell).allSatisfy {
                rect.contains(map.convert($0, toPointTo: map))
            })
        }
    }

    @Test func changingDockHeightUpdatesTargetsWithoutMovingCamera() throws {
        let map = makeMap()
        let coordinator = HexMapViewRepresentable.Coordinator(grid: HexGridService())
        coordinator.powerUpBottomInset = 76
        let collapsed = try #require(coordinator.powerUpWindow(in: map))
        coordinator.powerUpBottomInset = 300
        let expanded = try #require(coordinator.powerUpWindow(in: map))
        #expect(!expanded.isEmpty)
        #expect(expanded.count < collapsed.count)
        #expect(Set(expanded).isSubset(of: Set(collapsed)))
    }

    @Test func fullyCoveredMapHasNoTargets() throws {
        let map = makeMap()
        let coordinator = HexMapViewRepresentable.Coordinator(grid: HexGridService())
        coordinator.powerUpBottomInset = map.bounds.height
        #expect(try #require(coordinator.powerUpWindow(in: map)).isEmpty)
    }
}
