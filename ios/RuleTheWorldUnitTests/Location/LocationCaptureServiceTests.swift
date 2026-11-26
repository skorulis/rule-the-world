import CoreLocation
import Foundation
import Testing
@testable import RuleTheWorld

@MainActor
struct LocationCaptureServiceTests {
    private let grid = HexGridService()

    private func makeService(
        haptics: any CaptureHaptics = UICaptureHaptics(),
        onNewDailyHex: @escaping () -> Void = {}
    ) throws -> LocationCaptureService {
        let database = try AppDatabase.inMemory()
        let store = HexInfoStore(database: database)
        let logStore = HexVisitLogStore(database: database)
        return LocationCaptureService(
            grid: grid, store: store, logStore: logStore, haptics: haptics, onNewDailyHex: onNewDailyHex
        )
    }

    private func sample(
        speed: Double?,
        accuracy: Double = 10,
        latitude: Double = -33.89,
        longitude: Double = 151.19,
        timestamp: Date = .now,
        locationType: LocationType = .foreground
    ) -> LocationSample {
        LocationSample(
            latitude: latitude,
            longitude: longitude,
            speed: speed,
            course: nil,
            horizontalAccuracy: accuracy,
            timestamp: timestamp,
            locationType: locationType
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
        #expect(log.locationType == .foreground)
        #expect(log.count == 1)
    }

    @Test func backgroundSampleWritesBackgroundLog() async throws {
        let service = try makeService()
        await service.handle(sample(speed: nil, locationType: .background))
        let log = try #require(try await service.logStore.all().first)
        #expect(log.locationType == .background)
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
        #expect(logs.first?.count == 1)
    }

    @Test func captureRestartMergesUploadedBackgroundVisit() async throws {
        let database = try AppDatabase.inMemory()
        let logStore = HexVisitLogStore(database: database)
        let firstService = LocationCaptureService(
            grid: grid, store: HexInfoStore(database: database), logStore: logStore
        )
        let sample = sample(speed: nil, locationType: .background)
        await firstService.handle(sample)
        let first = try #require(try await logStore.latest())
        try await logStore.markUploaded([first], acceptedIDs: [first.uploadID])
        let restartedService = LocationCaptureService(
            grid: grid, store: HexInfoStore(database: database), logStore: logStore
        )
        await restartedService.handle(sample)
        let logs = try await logStore.all()
        #expect(logs.count == 1)
        #expect(logs.first?.id == first.id)
        #expect(logs.first?.uploadID == first.uploadID)
        #expect(logs.first?.count == 1)
        #expect(logs.first?.uploaded == false)
        #expect(logs.first?.locationType == .background)
    }

    @Test func differentCellsAppendLogRows() async throws {
        let service = try makeService()
        await service.handle(sample(speed: nil, latitude: -33.89, longitude: 151.19))
        await service.handle(sample(speed: nil, latitude: -33.95, longitude: 151.19))
        let logs = try await service.logStore.all()
        #expect(logs.count == 2)
    }

    @Test func returningToCellSameDayDoesNotAddVisitScoreOrLogRow() async throws {
        let service = try makeService()
        let cellSample = sample(speed: 1.0, latitude: -33.89, longitude: 151.19)
        let cell = cellOf(cellSample)
        await service.handle(cellSample)
        await service.handle(sample(speed: 1.0, latitude: -33.95, longitude: 151.19))
        await service.handle(cellSample)
        let visit = try #require(try await service.store.visit(for: cell))
        #expect(visit.total == 1)
        #expect(visit.score == 1)
        let logs = try await service.logStore.all()
        #expect(logs.count == 2)
        #expect(logs.map(\.count) == [1, 1])
        #expect(try await service.logStore.visitCount(for: cell) == 1)
    }

    @Test func randomNearbyVisitsUpdateLogAndHexScores() async throws {
        let service = try makeService()
        let origin = sample(speed: 1)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try await service.addRandomNearbyVisits(near: origin.coordinate, now: now)
        let logs = try await service.logStore.all()
        #expect(logs.count == 5)
        #expect(Set(logs.map(\.cell)).count == 5)
        for (index, log) in logs.enumerated() {
            #expect(log.timestamp == now.addingTimeInterval(Double(index - 5) * 60))
            let location = CLLocation(latitude: log.latitude, longitude: log.longitude)
            let center = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            #expect(location.distance(from: center) <= 505)
            #expect(grid.cell(containing: location.coordinate, resolution: HexGridService.baseResolution) == log.cell)
            #expect(log.score == 1)
            #expect(log.count == 1)
            let visit = try await service.store.visit(for: log.cell)
            #expect(visit?.score == 1)
            #expect(visit?.lastVisit == log.timestamp)
            #expect(service.store.snapshot.states[log.cell] != nil)
        }
    }

    @Test func repeatedRandomNearbyVisitsAddFiveLogEntriesEachTime() async throws {
        let service = try makeService()
        let origin = sample(speed: 1)
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        try await service.addRandomNearbyVisits(near: origin.coordinate, now: now)
        try await service.addRandomNearbyVisits(near: origin.coordinate, now: now.addingTimeInterval(86_400))
        #expect(try await service.logStore.all().count == 10)
    }

    @Test func randomNearbyVisitsRejectInvalidLocation() async throws {
        let service = try makeService()
        await #expect(throws: (any Error).self) {
            try await service.addRandomNearbyVisits(near: CLLocationCoordinate2D(latitude: 91, longitude: 0))
        }
        #expect(try await service.logStore.all().isEmpty)
        #expect(service.store.snapshot.states.isEmpty)
    }

    @Test func firstVisitTriggersVisitHaptic() async throws {
        let haptics = CaptureHapticsSpy()
        let service = try makeService(haptics: haptics)
        await service.handle(sample(speed: 30 / 3.6))
        #expect(haptics.visitCount == 1)
        #expect(haptics.captureCount == 0)
    }

    @Test func visitTakingOwnershipTriggersCaptureHaptic() async throws {
        let haptics = CaptureHapticsSpy()
        let service = try makeService(haptics: haptics)
        await service.handle(sample(speed: 1.0))
        #expect(haptics.captureCount == 1)
        #expect(haptics.visitCount == 0)
    }

    @Test func visitBeatingRivalScoreTriggersCaptureHaptic() async throws {
        let haptics = CaptureHapticsSpy()
        let service = try makeService(haptics: haptics)
        let cell = cellOf(sample(speed: 1.0))
        _ = try await service.store.save(
            HexInfo(cell: cell, totals: HexTotals(totalVisits: 3, rivalScore: 0.5), userVisit: nil)
        )
        await service.handle(sample(speed: 1.0))
        #expect(haptics.captureCount == 1)
        #expect(haptics.visitCount == 0)
    }

    @Test func revisitWhileAlreadyOwnedTriggersVisitHaptic() async throws {
        let haptics = CaptureHapticsSpy()
        let service = try makeService(haptics: haptics)
        await service.handle(sample(speed: 1.0))
        await service.handle(sample(speed: 1.0, timestamp: .now.addingTimeInterval(86_400)))
        #expect(haptics.captureCount == 1)
        #expect(haptics.visitCount == 1)
    }

    @Test func rejectedSampleTriggersNoHaptic() async throws {
        let haptics = CaptureHapticsSpy()
        let service = try makeService(haptics: haptics)
        await service.handle(sample(speed: nil, accuracy: 150))
        #expect(haptics.visitCount == 0)
        #expect(haptics.captureCount == 0)
    }

}

extension LocationCaptureServiceTests {
    @Test func requestsSyncOnlyForFirstForegroundVisitPerHexPerDay() async throws {
        var requests = 0
        let service = try makeService(onNewDailyHex: { requests += 1 })
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        await service.handle(sample(speed: 30 / 3.6, timestamp: date))
        #expect(requests == 1)
        await service.handle(sample(speed: 1, timestamp: date))
        #expect(requests == 1)
        await service.handle(sample(speed: 1, latitude: -33.95, timestamp: date))
        #expect(requests == 2)
        await service.handle(sample(speed: 1, timestamp: date))
        #expect(requests == 2)
        await service.handle(sample(speed: 1, timestamp: date.addingTimeInterval(86_400)))
        #expect(requests == 3)
    }

    @Test func backgroundAndRejectedSamplesDoNotRequestSync() async throws {
        var requests = 0
        let service = try makeService(onNewDailyHex: { requests += 1 })
        await service.handle(sample(speed: 1, locationType: .background))
        await service.handle(sample(speed: 1, accuracy: 150, latitude: -33.95))
        #expect(requests == 0)
        #expect(try await service.logStore.all().count == 1)
    }

    @Test func restartedCaptureDoesNotRequestSyncForExistingDailyHex() async throws {
        var requests = 0
        let first = try makeService(onNewDailyHex: { requests += 1 })
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        await first.handle(sample(speed: 30 / 3.6, timestamp: date))
        let restarted = LocationCaptureService(
            grid: grid, store: first.store, logStore: first.logStore, onNewDailyHex: { requests += 1 }
        )
        await restarted.handle(sample(speed: 1, timestamp: date))
        #expect(requests == 1)
        #expect(try await first.logStore.all().count == 1)
    }

    private func store(of service: LocationCaptureService) -> HexInfoStore {
        service.store
    }
}

@MainActor
private final class CaptureHapticsSpy: CaptureHaptics {
    var visitCount = 0
    var captureCount = 0
    func visitFeedback() { visitCount += 1 }
    func captureFeedback() { captureCount += 1 }
}
