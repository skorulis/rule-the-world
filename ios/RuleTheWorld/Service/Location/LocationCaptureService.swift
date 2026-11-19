import CoreLocation
import Foundation
import OSLog

@MainActor
final class LocationCaptureService {
    private let grid: HexGridService
    let store: HexVisitStore
    let logStore: HexVisitLogStore
    private var task: Task<Void, Never>?

    struct Recorded: Equatable {
        let cell: HexCell
        let score: Double
        let date: Date
    }

    private(set) var lastRecorded: Recorded?

    init(grid: HexGridService, store: HexVisitStore, logStore: HexVisitLogStore) {
        self.grid = grid
        self.store = store
        self.logStore = logStore
    }

    func start(samples: AsyncStream<LocationSample>) {
        task = Task {
            for await sample in samples {
                await handle(sample)
            }
        }
    }

    func addRandomNearbyVisits(near coordinate: CLLocationCoordinate2D, now: Date = .now) async throws {
        guard CLLocationCoordinate2DIsValid(coordinate) else {
            throw NearbyVisitError.invalidLocation
        }
        let latitude = coordinate.latitude * .pi / 180
        let longitude = coordinate.longitude * .pi / 180
        var samples: [(HexCell, LocationSample)] = []
        var cells = Set<HexCell>()
        if let latest = try await logStore.latest() {
            cells.insert(latest.cell)
        }
        for _ in 0..<100 {
            let bearing = Double.random(in: 0..<(2 * .pi))
            let distance = sqrt(Double.random(in: 0...1)) * 500 / 6_371_000
            let nearbyLatitude = asin(sin(latitude) * cos(distance) + cos(latitude) * sin(distance) * cos(bearing))
            let nearbyLongitude = longitude + atan2(
                sin(bearing) * sin(distance) * cos(latitude),
                cos(distance) - sin(latitude) * sin(nearbyLatitude)
            )
            let sample = LocationSample(
                latitude: nearbyLatitude * 180 / .pi,
                longitude: (nearbyLongitude * 180 / .pi + 540).truncatingRemainder(dividingBy: 360) - 180,
                speed: 1,
                course: nil,
                horizontalAccuracy: 10,
                timestamp: now.addingTimeInterval(Double(samples.count - 5) * 60)
            )
            let cell = grid.cell(containing: sample.coordinate, resolution: HexGridService.baseResolution)
            guard cell.rawValue != 0, cells.insert(cell).inserted else { continue }
            samples.append((cell, sample))
            if samples.count == 5 { break }
        }
        guard samples.count == 5 else { throw NearbyVisitError.notEnoughCells }
        for (cell, sample) in samples {
            _ = try await store.recordVisit(cell, at: sample.timestamp)
            _ = try await logStore.record(HexVisitLog(sample: sample, cell: cell, score: 1))
        }
    }

    private enum NearbyVisitError: LocalizedError {
        case invalidLocation
        case notEnoughCells

        var errorDescription: String? {
            switch self {
            case .invalidLocation: "The current location is invalid."
            case .notEnoughCells: "Could not find five nearby hexagons. Please try again."
            }
        }
    }

    func handle(_ sample: LocationSample) async {
        guard VisitScorePolicy.isAcceptable(sample) else { return }
        let cell = grid.cell(
            containing: sample.coordinate,
            resolution: HexGridService.baseResolution
        )
        let score = VisitScorePolicy.score(forSpeed: sample.speed)
        if let last = lastRecorded,
           last.cell == cell,
           score <= last.score,
           HexVisit.scoringCalendar.isDate(last.date, inSameDayAs: sample.timestamp) {
            return
        }
        do {
            _ = try await store.recordVisit(cell, score: score, at: sample.timestamp)
            _ = try await logStore.record(HexVisitLog(sample: sample, cell: cell, score: score))
            lastRecorded = Recorded(cell: cell, score: score, date: sample.timestamp)
        } catch {
            Logger().error("recordVisit failed: \(error)")
        }
    }
}
