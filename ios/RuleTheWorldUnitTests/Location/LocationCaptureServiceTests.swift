import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct LocationCaptureServiceTests {
    private let grid = HexGridService()

    private func makeService() throws -> LocationCaptureService {
        let database = try AppDatabase.inMemory()
        let store = HexVisitStore(database: database)
        let logStore = HexVisitLogStore(database: database)
        return LocationCaptureService(grid: grid, store: store, logStore: logStore)
    }

    private func sample(
        speed: Double?,
        accuracy: Double = 10,
        latitude: Double = -33.89,
        longitude: Double = 151.19,
        timestamp: Date = .now
    ) -> LocationSample {
        LocationSample(
            latitude: latitude,
            longitude: longitude,
            speed: speed,
            course: nil,
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

    @Test func acceptedSampleWritesVisitLog() async throws {
        let service = try makeService()
        let sample = sample(speed: 1.0)
        await service.handle(sample)
        let logs = try await service.logStore.all()
        #expect(logs.count == 1)
        let log = try #require(logs.first)
        #expect(log.id != nil)
        #expect(log.timestamp == sample.timestamp)
        #expect(log.cell == cellOf(sample))
        #expect(log.latitude == sample.latitude)
        #expect(log.longitude == sample.longitude)
        #expect(log.speed == 1.0)
        #expect(log.score == 1)
    }

    @Test func rejectedSampleWritesNoVisitLog() async throws {
        let service = try makeService()
        await service.handle(sample(speed: nil, accuracy: 150))
        #expect(try await service.logStore.all().isEmpty)
    }

    @Test func duplicateSampleLeavesOneLogRow() async throws {
        let service = try makeService()
        let sample = sample(speed: nil)
        await service.handle(sample)
        await service.handle(sample)
        #expect(try await service.logStore.all().count == 1)
    }

    @Test func sameCellMergesToSingleRowWithMaxScoreMinSpeed() async throws {
        let service = try makeService()
        await service.handle(sample(speed: 30 / 3.6))
        await service.handle(sample(speed: 1.0))
        let logs = try await service.logStore.all()
        #expect(logs.count == 1)
        #expect(logs.first?.score == 1)
        #expect(logs.first?.speed == 1.0)
    }

    @Test func differentCellsAppendLogRows() async throws {
        let service = try makeService()
        await service.handle(sample(speed: nil, latitude: -33.89, longitude: 151.19))
        await service.handle(sample(speed: nil, latitude: -33.95, longitude: 151.19))
        let logs = try await service.logStore.all()
        #expect(logs.count == 2)
    }

    private func store(of service: LocationCaptureService) -> HexVisitStore {
        service.store
    }
}
