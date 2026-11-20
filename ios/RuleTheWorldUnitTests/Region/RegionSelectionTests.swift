import Foundation
import MapKit
import Observation
import Testing
@testable import RuleTheWorld

@MainActor
struct RegionSelectionTests {
    private func model(provider: ControlledRegionProvider) throws -> HexMapViewModel {
        let database = try AppDatabase.inMemory()
        return HexMapViewModel(
            grid: HexGridService(), store: HexInfoStore(database: database),
            logStore: HexVisitLogStore(database: database),
            locationService: LocationService(), boundaries: provider, totalsProvider: EmptyTotalsProvider()
        )
    }

    private func move(_ model: HexMapViewModel, longitude: Double, width: Double = 2_000_000) {
        model.cameraChanged(
            zoomScale: 0.0001,
            center: CLLocationCoordinate2D(latitude: 0, longitude: longitude),
            visibleWidthMeters: width
        )
    }

    private func selection(id: String, level: RegionOverlayPolicy.Level = .medium) -> MapRegionSelection {
        MapRegionSelection(boundary: MapRegionBoundary(id: id, name: id, kind: .country, polygons: []), level: level)
    }

    private func complete(
        _ request: ControlledRegionProvider.Request,
        with selection: MapRegionSelection?,
        observing model: HexMapViewModel
    ) async {
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = model.selectedRegion
            } onChange: {
                Task { @MainActor in continuation.resume() }
            }
            request.completion.resume(returning: selection)
        }
    }

    @Test func selectsCountryThenClearsOverOceanAndWhenZoomedIn() async throws {
        let provider = ControlledRegionProvider()
        let model = try model(provider: provider)
        defer { model.cancelRegionSelection() }
        move(model, longitude: 1)
        let land = await provider.nextRequest()
        await complete(land, with: selection(id: "land"), observing: model)
        #expect(model.selectedRegion?.boundary.id == "land")

        move(model, longitude: 20)
        let ocean = await provider.nextRequest()
        await complete(ocean, with: nil, observing: model)
        #expect(model.selectedRegion == nil)

        move(model, longitude: 1)
        let landAgain = await provider.nextRequest()
        await complete(landAgain, with: selection(id: "land"), observing: model)
        move(model, longitude: 1, width: 100_000)
        #expect(model.selectedRegion == nil)
        #expect(!model.isLoadingRegions)
    }

    @Test func cancellingBeforeWorkerStartsDoesNotConsumeNextCamera() async throws {
        let provider = ControlledRegionProvider()
        let model = try model(provider: provider)
        defer { model.cancelRegionSelection() }
        move(model, longitude: 1)
        model.cancelRegionSelection()
        move(model, longitude: 2)
        let latest = await provider.nextRequest()
        #expect(latest.longitude == 2)
        await complete(latest, with: selection(id: "latest"), observing: model)
        #expect(model.selectedRegion?.boundary.id == "latest")
    }

    @Test func dataFailureDisablesOnlyOptionalCountryLayer() async throws {
        let provider = ControlledRegionProvider()
        let model = try model(provider: provider)
        move(model, longitude: 1)
        let request = await provider.nextRequest()
        await withCheckedContinuation { continuation in
            withObservationTracking {
                _ = model.isLoadingRegions
            } onChange: {
                Task { @MainActor in continuation.resume() }
            }
            request.completion.resume(throwing: RegionBoundaryError.missingResource)
        }
        #expect(model.selectedRegion == nil)
        #expect(!model.isLoadingRegions)
        #expect(model.showGrid)
        move(model, longitude: 2)
        #expect(!model.isLoadingRegions)
    }

    @Test func coalescesCameraEventsAndDiscardsStaleLookup() async throws {
        let provider = ControlledRegionProvider()
        let model = try model(provider: provider)
        defer { model.cancelRegionSelection() }
        move(model, longitude: 1)
        let stale = await provider.nextRequest()
        move(model, longitude: 2)
        move(model, longitude: 3, width: 7_000_000)
        stale.completion.resume(returning: selection(id: "stale"))
        let latest = await provider.nextRequest()
        #expect(model.selectedRegion == nil)
        #expect(latest.longitude == 3)
        #expect(latest.level == .coarse)
        await complete(latest, with: selection(id: "latest", level: .coarse), observing: model)
        #expect(model.selectedRegion?.boundary.id == "latest")
        #expect(model.selectedRegion?.level == .coarse)
    }
}

private struct EmptyTotalsProvider: HexTotalsProviding {
    func totals(for cell: HexCell) async throws -> HexInfo {
        HexInfo(cell: cell, totals: HexTotals(totalVisits: 0, rivalScore: 0), userVisit: nil)
    }
}

private actor ControlledRegionProvider: RegionBoundaryProviding {
    struct Request: Sendable {
        let longitude: Double
        let level: RegionOverlayPolicy.Level
        let completion: CheckedContinuation<MapRegionSelection?, Error>
    }

    private var requests: [Request] = []
    private var waiter: CheckedContinuation<Request, Never>?

    func selection(
        latitude: Double,
        longitude: Double,
        level: RegionOverlayPolicy.Level
    ) async throws -> MapRegionSelection? {
        try await withCheckedThrowingContinuation { continuation in
            let request = Request(longitude: longitude, level: level, completion: continuation)
            if let waiter {
                self.waiter = nil
                waiter.resume(returning: request)
            } else {
                requests.append(request)
            }
        }
    }

    func nextRequest() async -> Request {
        if !requests.isEmpty { return requests.removeFirst() }
        return await withCheckedContinuation { waiter = $0 }
    }
}
