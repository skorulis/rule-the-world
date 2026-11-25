import ASKCoordinator
import MapKit
import SwiftUI

struct HexMapView: View {
    @State var model: HexMapViewModel
    @State var powerUpInventory: PowerUpInventoryViewModel
    @Environment(\.coordinator) private var coordinator
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        HexMapViewRepresentable(
            initialRegion: model.initialRegion,
            snapshot: model.snapshot,
            mode: model.mapMode,
            grid: model.grid,
            userStatus: model.userStatus,
            selectedRegion: model.selectedRegion,
            onCameraChange: { zoomScale, region, visibleWidthMeters in
                model.cameraChanged(zoomScale: zoomScale, region: region, visibleWidthMeters: visibleWidthMeters)
            },
            onTap: { coordinate in
                model.tapped(coordinate: coordinate)
            }
        )
        .ignoresSafeArea()
        .overlay(alignment: .topLeading) {
            if let region = model.selectedRegion {
                Text(region.boundary.name)
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                coordinator?.present(MainPath.powerUpInventory(powerUpInventory), style: .sheet)
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text(powerUpInventory.totalCount.formatted())
                        .monospacedDigit()
                }
                .font(.headline)
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(.ultraThinMaterial, in: .capsule)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Power-ups")
            .accessibilityValue(powerUpInventory.totalCount.formatted())
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            Picker("Map mode", selection: $model.mapMode) {
                ForEach(HexMapMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
        .animation(.default, value: model.selectedRegion)
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            await powerUpInventory.load()
        }
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
