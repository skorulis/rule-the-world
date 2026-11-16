import Foundation
import OSLog

@MainActor
final class LocationCaptureService {
    private let grid: HexGridService
    let store: HexVisitStore
    private var task: Task<Void, Never>?

    struct Recorded: Equatable {
        let cell: HexCell
        let score: Double
        let date: Date
    }

    private(set) var lastRecorded: Recorded?

    init(grid: HexGridService, store: HexVisitStore) {
        self.grid = grid
        self.store = store
    }

    func start(samples: AsyncStream<LocationSample>) {
        task = Task {
            for await sample in samples {
                await handle(sample)
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
           Calendar.current.isDate(last.date, inSameDayAs: sample.timestamp) {
            return
        }
        do {
            _ = try await store.recordVisit(cell, score: score, at: sample.timestamp)
            lastRecorded = Recorded(cell: cell, score: score, date: sample.timestamp)
        } catch {
            Logger().error("recordVisit failed: \(error)")
        }
    }
}
