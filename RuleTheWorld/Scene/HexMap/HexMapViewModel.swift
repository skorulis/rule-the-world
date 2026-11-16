import ASKCore
import Knit
import KnitMacros
import MapKit
import Observation
import OSLog
import SwiftUI

@Observable
@MainActor
final class HexMapViewModel {
    let initialRegion: MKCoordinateRegion
    var displayedResolution: Int?
    var lastTappedCell: HexCell?
    var lastTappedVisit: HexVisit?
    var showGrid = true

    let grid: HexGridService
    private let store: HexVisitStore

    @Resolvable<Resolver>
    init(grid: HexGridService, store: HexVisitStore) {
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
        guard displayedResolution == HexGridService.baseResolution else { return }
        let cell = grid.cell(containing: coordinate, resolution: HexGridService.baseResolution)
        lastTappedCell = cell
        Task {
            do {
                lastTappedVisit = try await store.recordVisit(cell)
            } catch {
                Logger().error("recordVisit failed: \(error)")
            }
        }
    }
}
