import MapKit
import SwiftUI

struct HexMapView: View {
    @State var model: HexMapViewModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HexMapViewRepresentable(
            initialRegion: model.initialRegion,
            snapshot: model.snapshot,
            showGrid: model.showGrid,
            grid: model.grid,
            userStatus: model.userStatus,
            selectedRegion: model.selectedRegion,
            onCameraChange: { zoomScale, center, visibleWidthMeters in
                model.cameraChanged(zoomScale: zoomScale, center: center, visibleWidthMeters: visibleWidthMeters)
            },
            onTap: { coordinate in
                model.tapped(coordinate: coordinate)
            }
        )
        .ignoresSafeArea()
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await model.refreshGameDay()
        }
        .onDisappear { model.cancelRegionSelection() }
        .sheet(item: $model.selectedCell) { cell in
            HexCellDetailView(model: model.makeCellDetailViewModel(for: cell))
        }
    }
}
