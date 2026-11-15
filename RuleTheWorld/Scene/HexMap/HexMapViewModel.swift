import ASKCore
import Knit
import KnitMacros
import MapKit
import Observation
import SwiftUI

@Observable
@MainActor
final class HexMapViewModel {
    let initialRegion: MKCoordinateRegion
    var displayedResolution: Int?
    var lastTappedCell: HexCell?
    var showGrid = true

    let grid: HexGridService
    private let store: HexOwnershipStore

    @Resolvable<Resolver>
    init(grid: HexGridService, store: HexOwnershipStore) {
        self.grid = grid
        self.store = store
        self.initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    var snapshot: HexOwnershipSnapshot {
        store.snapshot
    }

    var showZoomInMessage: Bool {
        displayedResolution == nil
    }

    func cameraChanged(zoomScale: MKZoomScale, latitude: CLLocationDegrees) {
        let resolution = HexZoomPolicy.resolution(forZoomScale: zoomScale, latitude: latitude)
        if resolution != displayedResolution {
            displayedResolution = resolution
        }
    }

    func tapped(coordinate: CLLocationCoordinate2D) {
        guard displayedResolution == HexOwnershipStore.baseResolution else { return }
        let cell = grid.cell(containing: coordinate, resolution: HexOwnershipStore.baseResolution)
        lastTappedCell = cell
        store.toggle(cell)
    }
}
