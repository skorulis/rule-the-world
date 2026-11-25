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
    var selectedCell: HexCell?
    var mapMode: HexMapMode = .territory

    private(set) var selectedRegion: MapRegionSelection?
    private(set) var isLoadingRegions = false

    let grid: HexGridService
    private let store: HexInfoStore
    private let logStore: HexVisitLogStore
    private let locationService: LocationService
    private let boundaries: any RegionBoundaryProviding
    private let totalsProvider: any HexTotalsProviding
    private let regionNames: RegionNameCatalog
    private var regionLevel: RegionOverlayPolicy.Level?
    @ObservationIgnored private var selectionTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCamera: RegionCameraRequest?
    @ObservationIgnored private var cameraRevision = 0
    @ObservationIgnored private var regionLoadFailed = false
    @ObservationIgnored private var fetchTask: Task<Void, Never>?
    @ObservationIgnored private var pendingFetch: MKCoordinateRegion?
    @ObservationIgnored private var fetchCooldownUntil: Date?

    private struct RegionCameraRequest {
        let latitude: Double
        let longitude: Double
        let level: RegionOverlayPolicy.Level
        let revision: Int
    }

    @Resolvable<Resolver>
    init(
        grid: HexGridService,
        store: HexInfoStore,
        logStore: HexVisitLogStore,
        locationService: LocationService,
        boundaries: RegionBoundaryProviding,
        totalsProvider: HexTotalsProviding,
        regionNames: RegionNameCatalog = RegionNameCatalog()
    ) {
        self.grid = grid
        self.store = store
        self.logStore = logStore
        self.locationService = locationService
        self.boundaries = boundaries
        self.totalsProvider = totalsProvider
        self.regionNames = regionNames
        self.initialRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
    }

    var snapshot: HexOwnershipSnapshot {
        store.snapshot
    }

    func refreshGameDay() async {
        while !Task.isCancelled {
            await store.reload()
            let calendar = HexVisit.scoringCalendar
            let now = Date.now
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) else {
                return
            }
            do {
                try await Task.sleep(for: .seconds(max(nextDay.timeIntervalSinceNow, 0.1)))
            } catch {
                return
            }
        }
    }

    var userStatus: UserMapStatus? {
        UserMapStatus.make(sample: locationService.latestSample, heading: locationService.heading)
    }

    func cameraChanged(zoomScale: MKZoomScale, region: MKCoordinateRegion, visibleWidthMeters: Double) {
        let center = region.center
        let resolution = HexZoomPolicy.resolution(forZoomScale: zoomScale, latitude: center.latitude)
        if resolution != displayedResolution {
            displayedResolution = resolution
        }
        updatePendingFetch(region: region, resolution: resolution)
        cameraRevision += 1
        regionLevel = RegionOverlayPolicy.level(visibleWidthMeters: visibleWidthMeters, previous: regionLevel)
        guard let regionLevel, !regionLoadFailed else {
            cancelRegionSelection()
            return
        }
        pendingCamera = RegionCameraRequest(
            latitude: center.latitude, longitude: center.longitude, level: regionLevel, revision: cameraRevision
        )
        guard selectionTask == nil else { return }
        selectionTask = Task { [weak self] in
            await self?.updateRegionSelection()
        }
    }

    private func updatePendingFetch(region: MKCoordinateRegion, resolution: Int?) {
        guard resolution == HexGridService.baseResolution,
              fetchCooldownUntil.map({ Date.now >= $0 }) ?? true else {
            pendingFetch = nil
            return
        }
        pendingFetch = region
        guard fetchTask == nil else { return }
        fetchTask = Task { [weak self] in
            await self?.updateVisibleHexes()
        }
    }

    private func updateVisibleHexes() async {
        defer { fetchTask = nil }
        while let region = pendingFetch {
            pendingFetch = nil
            let cells = Array(
                grid.cells(in: region, resolution: HexGridService.baseResolution)
                    .prefix(HexInfoRefreshPolicy.maxCellsPerRequest)
            )
            do {
                let stale = try await store.staleCells(in: cells)
                guard !Task.isCancelled else { return }
                if !stale.isEmpty {
                    let infos = try await totalsProvider.totals(for: stale)
                    guard !Task.isCancelled else { return }
                    try await store.restore(infos)
                }
                fetchCooldownUntil = nil
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                guard !Task.isCancelled else { return }
                Logger().error("Hex info fetch failed: \(error)")
                fetchCooldownUntil = Date.now.addingTimeInterval(HexInfoRefreshPolicy.failureCooldown)
            }
        }
    }

    func cancelRegionSelection() {
        cameraRevision += 1
        selectionTask?.cancel()
        selectionTask = nil
        pendingCamera = nil
        isLoadingRegions = false
        if selectedRegion != nil {
            selectedRegion = nil
        }
        regionLevel = nil
        fetchTask?.cancel()
        fetchTask = nil
        pendingFetch = nil
    }

    private func updateRegionSelection() async {
        guard !Task.isCancelled else { return }
        while let request = pendingCamera {
            pendingCamera = nil
            isLoadingRegions = true
            do {
                let selection = try await boundaries.selection(
                    latitude: request.latitude, longitude: request.longitude, level: request.level
                )
                guard !Task.isCancelled else { return }
                if request.revision == cameraRevision, selection != selectedRegion {
                    selectedRegion = selection
                }
                isLoadingRegions = false
                try await Task.sleep(for: .milliseconds(100))
            } catch {
                guard !Task.isCancelled else { return }
                Logger().error("Country boundary lookup failed: \(error)")
                regionLoadFailed = true
                cancelRegionSelection()
                return
            }
        }
        selectionTask = nil
    }

    func tapped(coordinate: CLLocationCoordinate2D) {
        guard displayedResolution == HexGridService.baseResolution else { return }
        selectedCell = grid.cell(containing: coordinate, resolution: HexGridService.baseResolution)
    }

    func makeCellDetailViewModel(for cell: HexCell) -> HexCellDetailViewModel {
        HexCellDetailViewModel(
            cell: cell, store: store, logStore: logStore,
            totalsProvider: totalsProvider, regionNames: regionNames
        )
    }
}
