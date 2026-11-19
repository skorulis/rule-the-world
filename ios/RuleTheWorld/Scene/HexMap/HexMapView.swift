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
            userStatus: model.userStatus,
            selectedRegion: model.selectedRegion,
            onCameraChange: { zoomScale, center, visibleWidthMeters in
                model.cameraChanged(zoomScale: zoomScale, center: center, visibleWidthMeters: visibleWidthMeters)
            },
            onTap: { coordinate in
                #if DEBUG
                model.tapped(coordinate: coordinate)
                #endif
            }
        )
        .ignoresSafeArea()
        .onDisappear { model.cancelRegionSelection() }
        .overlay(alignment: .top) {
            HexMapHUD(
                resolution: model.displayedResolution,
                lastTappedCell: model.lastTappedCell,
                lastTappedVisit: model.lastTappedVisit,
                authorizationDescription: model.authorizationDescription,
                speedKmh: model.latestSample?.speed.map { $0 * 3.6 },
                accuracy: model.latestSample?.horizontalAccuracy,
                showGrid: $model.showGrid
            )
        }
    }
}
