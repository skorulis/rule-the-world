import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct LocationCaptureServiceTests {
    private let grid = HexGridService()

    private func makeService() throws -> LocationCaptureService {
        let store = try HexVisitStore(database: AppDatabase.inMemory())
        return LocationCaptureService(grid: grid, store: store)
    }

    private func sample(
        speed: Double?,
        accuracy: Double = 10,
        timestamp: Date = .now
    ) -> LocationSample {
        LocationSample(
            latitude: -33.89,
            longitude: 151.19,
            speed: speed,
            horizontalAccuracy: accuracy,
            timestamp: timestamp
        )
    }

    private func cellOf(_ sample: LocationSample) -> HexCell {
        grid.cell(containing: sample.coordinate, resolution: HexGridService.baseResolution)
    }

    @Test func walkingSampleScoresOne() async throws {
        let service = try makeService()
        let sample = sample(speed: 1.0)
        await service.handle(sample)
        let visit = try await store(of: service).visit(for: cellOf(sample))
        #expect(visit?.score == 1)
    }

    @Test func thirtyKmhScoresHalf() async throws {
        let service = try makeService()
        let sample = sample(speed: 30 / 3.6)
        await service.handle(sample)
        let visit = try await store(of: service).visit(for: cellOf(sample))
        #expect(visit?.score == 0.5)
    }

    @Test func highSpeedRecordsZeroScoreVisit() async throws {
        let service = try makeService()
        let sample = sample(speed: 160 / 3.6)
        await service.handle(sample)
        let visit = try await store(of: service).visit(for: cellOf(sample))
        #expect(visit != nil)
        #expect(visit?.score == 0)
    }

    @Test func poorAccuracyIsRejected() async throws {
        let service = try makeService()
        let sample = sample(speed: nil, accuracy: 150)
        await service.handle(sample)
        let visit = try await store(of: service).visit(for: cellOf(sample))
        #expect(visit == nil)
    }

    @Test func negativeAccuracyIsRejected() async throws {
        let service = try makeService()
        let sample = sample(speed: nil, accuracy: -1)
        await service.handle(sample)
        let visit = try await store(of: service).visit(for: cellOf(sample))
        #expect(visit == nil)
    }

    @Test func duplicateSampleSkipsSecondWrite() async throws {
        let service = try makeService()
        let sample = sample(speed: nil)
        await service.handle(sample)
        let first = service.lastRecorded
        await service.handle(sample)
        #expect(service.lastRecorded?.date == first?.date)
        let visit = try await store(of: service).visit(for: cellOf(sample))
        #expect(visit?.score == 1)
    }

    private func store(of service: LocationCaptureService) -> HexVisitStore {
        service.store
    }
}
