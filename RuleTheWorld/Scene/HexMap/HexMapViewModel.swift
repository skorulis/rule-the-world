import ASKCore
import Knit
import KnitMacros
import MapKit
import Observation
import SwiftUI

@Observable
@MainActor
final class HexMapViewModel {
    var cameraPosition: MapCameraPosition
    var visibleRegion: MKCoordinateRegion?
    var displayedResolution: Int?
    var tiles: [HexTile] = []
    var lastTappedCell: HexCell?
    var showGrid = true

    private let grid: HexGridService
    private let store: HexOwnershipStore
    private var tileTask: Task<Void, Never>?

    @Resolvable<Resolver>
    init(grid: HexGridService, store: HexOwnershipStore) {
        self.grid = grid
        self.store = store
        self.cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        )
    }

    var showZoomInMessage: Bool {
        displayedResolution == nil
    }

    func cameraChanged(_ region: MKCoordinateRegion) {
        visibleRegion = region
        recomputeTiles()
    }

    func tapped(coordinate: CLLocationCoordinate2D) {
        guard displayedResolution == HexOwnershipStore.baseResolution else { return }
        let cell = grid.cell(containing: coordinate, resolution: HexOwnershipStore.baseResolution)
        lastTappedCell = cell
        store.toggle(cell)
        recomputeTiles()
    }

    private func recomputeTiles() {
        tileTask?.cancel()
        guard let region = visibleRegion else {
            displayedResolution = nil
            tiles = []
            return
        }
        let resolution = HexZoomPolicy.resolution(for: region)
        displayedResolution = resolution
        guard let resolution else {
            tiles = []
            return
        }
        let states = store.aggregated(at: resolution, grid: grid)
        tileTask = Task.detached { [grid] in
            let cells = grid.cells(in: region, resolution: resolution)
            let newTiles = cells.map { cell in
                HexTile(
                    cell: cell,
                    boundary: grid.boundary(of: cell),
                    state: states[cell] ?? .unclaimed
                )
            }
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self.tiles = newTiles
            }
        }
    }
}
