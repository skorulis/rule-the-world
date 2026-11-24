import Foundation
import MapKit
import Testing
@testable import RuleTheWorld

@MainActor
struct HexViewportFetchTests {
    private let grid = HexGridService()
    private let sydney = CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19)

    private var baseZoomScale: MKZoomScale {
        let metersPerPoint = 2_000 / 850.0
        return 1 / (metersPerPoint * MKMapPointsPerMeterAtLatitude(sydney.latitude))
    }

    private func region(longitude: Double = 151.19, span: Double = 0.005) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: sydney.latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }

    private func model(provider: ControlledTotalsProvider) throws -> HexMapViewModel {
        let database = try AppDatabase.inMemory()
        return HexMapViewModel(
            grid: grid, store: HexInfoStore(database: database),
            logStore: HexVisitLogStore(database: database),
            locationService: LocationService(), boundaries: NilRegionProvider(), totalsProvider: provider
        )
    }

    private func infos(for cells: [HexCell]) -> [HexInfo] {
        cells.map { HexInfo(cell: $0, totals: HexTotals(totalVisits: 0, rivalScore: 0), userVisit: nil, lastUpdate: .now) }
    }

    @Test func fetchesVisibleCellsAtBaseResolution() async throws {
        let provider = ControlledTotalsProvider()
        let model = try model(provider: provider)
        defer { model.cancelRegionSelection() }
        let region = region()
        model.cameraChanged(zoomScale: baseZoomScale, region: region, visibleWidthMeters: 2_000)
        let request = await provider.nextRequest()
        #expect(Set(request.cells) == Set(grid.cells(in: region, resolution: HexGridService.baseResolution)))
        request.completion.resume(returning: infos(for: request.cells))
    }

    @Test func doesNotFetchWhenZoomedOut() async throws {
        let provider = ControlledTotalsProvider()
        let model = try model(provider: provider)
        defer { model.cancelRegionSelection() }
        model.cameraChanged(zoomScale: baseZoomScale / 32, region: region(span: 0.5), visibleWidthMeters: 60_000)
        try await Task.sleep(for: .milliseconds(200))
        #expect(await provider.requestCount == 0)
    }

    @Test func onlyRefreshesStaleOrMissingCells() async throws {
        let provider = ControlledTotalsProvider()
        let database = try AppDatabase.inMemory()
        let store = HexInfoStore(database: database)
        let model = HexMapViewModel(
            grid: grid, store: store,
            logStore: HexVisitLogStore(database: database),
            locationService: LocationService(), boundaries: NilRegionProvider(), totalsProvider: provider
        )
        defer { model.cancelRegionSelection() }
        let region = region()
        let visible = grid.cells(in: region, resolution: HexGridService.baseResolution)
        let staleCell = try #require(visible.first)
        var fresh = infos(for: visible)
        fresh.removeAll { $0.cell == staleCell }
        try await store.restore(fresh)
        try await store.restore([
            HexInfo(
                cell: staleCell, totals: nil, userVisit: nil,
                lastUpdate: .now.addingTimeInterval(-2 * HexInfoRefreshPolicy.staleInterval)
            )
        ])
        model.cameraChanged(zoomScale: baseZoomScale, region: region, visibleWidthMeters: 2_000)
        let request = await provider.nextRequest()
        #expect(request.cells == [staleCell])
        request.completion.resume(returning: infos(for: request.cells))
    }

    @Test func keepsOnlyOneRequestInFlightAndUsesLatestRegion() async throws {
        let provider = ControlledTotalsProvider()
        let model = try model(provider: provider)
        defer { model.cancelRegionSelection() }
        model.cameraChanged(zoomScale: baseZoomScale, region: region(longitude: 151.19), visibleWidthMeters: 2_000)
        let first = await provider.nextRequest()
        model.cameraChanged(zoomScale: baseZoomScale, region: region(longitude: 151.20), visibleWidthMeters: 2_000)
        model.cameraChanged(zoomScale: baseZoomScale, region: region(longitude: 151.21), visibleWidthMeters: 2_000)
        #expect(await provider.inFlightCount == 1)
        first.completion.resume(returning: infos(for: first.cells))
        let second = await provider.nextRequest()
        #expect(Set(second.cells) == Set(grid.cells(in: region(longitude: 151.21), resolution: HexGridService.baseResolution)))
        second.completion.resume(returning: infos(for: second.cells))
    }
}

private struct NilRegionProvider: RegionBoundaryProviding {
    func selection(
        latitude: Double,
        longitude: Double,
        level: RegionOverlayPolicy.Level
    ) async throws -> MapRegionSelection? {
        nil
    }
}

private actor ControlledTotalsProvider: HexTotalsProviding {
    struct Request: Sendable {
        let cells: [HexCell]
        let completion: CheckedContinuation<[HexInfo], Error>
    }

    private var pending: [Request] = []
    private var waiter: CheckedContinuation<Request, Never>?
    private(set) var requestCount = 0
    private(set) var inFlightCount = 0

    func totals(for cells: [HexCell]) async throws -> [HexInfo] {
        requestCount += 1
        inFlightCount += 1
        defer { inFlightCount -= 1 }
        return try await withCheckedThrowingContinuation { continuation in
            let request = Request(cells: cells, completion: continuation)
            if let waiter {
                self.waiter = nil
                waiter.resume(returning: request)
            } else {
                pending.append(request)
            }
        }
    }

    func nextRequest() async -> Request {
        if !pending.isEmpty { return pending.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }
}
