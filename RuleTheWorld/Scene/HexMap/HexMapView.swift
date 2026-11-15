import MapKit
import SwiftUI

struct HexMapView: View {
    @State var model: HexMapViewModel

    var body: some View {
        HexMapViewRepresentable(
            initialRegion: model.initialRegion,
            snapshot: model.snapshot,
            showGrid: model.showGrid,
            grid: model.grid,
            onCameraChange: { zoomScale, latitude in
                model.cameraChanged(zoomScale: zoomScale, latitude: latitude)
            },
            onTap: { coordinate in
                model.tapped(coordinate: coordinate)
            }
        )
        .ignoresSafeArea()
        .overlay(alignment: .top) {
            HexMapHUD(
                resolution: model.displayedResolution,
                lastTappedCell: model.lastTappedCell,
                showGrid: $model.showGrid
            )
        }
    }
}
