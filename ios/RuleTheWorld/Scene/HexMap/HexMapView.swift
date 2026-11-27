import ASKCoordinator
import MapKit
import SwiftUI

struct HexMapView: View {
    @State var model: HexMapViewModel
    @State var powerUpInventory: PowerUpInventoryViewModel
    @State private var isPowerUpDockExpanded = false
    @State private var topControlsHeight: CGFloat = 0
    @State private var regionControlsHeight: CGFloat = 0
    @State private var bottomControlsHeight: CGFloat = 0
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
            powerUpTopInset: max(topControlsHeight, regionControlsHeight),
            powerUpBottomInset: bottomControlsHeight,
            onPowerUpWindowProvider: { model.unobscuredPowerUpWindow = $0 },
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
                Button {
                    model.regionDetail = region.boundary
                } label: {
                    Text(region.boundary.name)
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Region details")
                .accessibilityValue(region.boundary.name)
                .padding()
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { regionControlsHeight = $0 }
                .onDisappear { regionControlsHeight = 0 }
            }
        }
        .overlay(alignment: .topTrailing) {
            HStack {
                Button {
                    coordinator?.push(MainPath.profile)
                } label: {
                    Image(systemName: "person.crop.circle")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(.ultraThinMaterial, in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")
                Button {
                    isPowerUpDockExpanded.toggle()
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
            }
            .padding()
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { topControlsHeight = $0 }
        }
        .overlay(alignment: .bottomTrailing) {
            Group {
                if isPowerUpDockExpanded {
                    PowerUpDockView(model: powerUpInventory) {
                        coordinator?.present(MainPath.powerUpInventory(powerUpInventory), style: .sheet)
                    } onClose: {
                        isPowerUpDockExpanded = false
                    }
                    .padding()
                } else {
                    mapModeControls
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { bottomControlsHeight = $0 }
        }
        .animation(.default, value: model.selectedRegion)
        .onAppear {
            powerUpInventory.mapWindowProvider = { model.powerUpWindow }
            powerUpInventory.mapIsAtHexResolution = model.displayedResolution == HexGridService.baseResolution
        }
        .onChange(of: model.displayedResolution) {
            powerUpInventory.mapIsAtHexResolution = model.displayedResolution == HexGridService.baseResolution
        }
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
        .sheet(item: $model.regionDetail) { region in
            NavigationStack {
                RegionDetailView(model: model.makeRegionDetailViewModel(for: region))
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { model.regionDetail = nil }
                        }
                    }
            }
        }
    }

    private var mapModeControls: some View {
        HStack(spacing: 4) {
            ForEach(HexMapMode.allCases) { mode in
                Button {
                    model.mapMode = mode
                } label: {
                    Image(mode.imageName)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .frame(width: 48, height: 48)
                        .background(
                            model.mapMode == mode ? Color.accentColor : Color.clear,
                            in: .circle
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mode.title)
                .accessibilityAddTraits(model.mapMode == mode ? .isSelected : [])
            }
        }
        .padding(4)
        .background(.ultraThinMaterial, in: .capsule)
        .padding()
    }
}
