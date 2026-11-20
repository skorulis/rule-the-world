import Foundation
import GRDB
import OSLog
import Observation

@Observable
@MainActor
final class HexVisitStore {
    private(set) var snapshot = HexOwnershipSnapshot(states: [:])

    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
        Task {
            await reload()
        }
    }

    func recordVisit(_ cell: HexCell, score: Double = 1, at date: Date = .now) async throws -> HexVisit {
        let visit = try await database.writer.write { db in
            let existing = try HexVisit.fetchOne(db, key: cell)
                ?? HexVisit(cell: cell, lastVisit: .distantPast, score: 0, lastScore: 0)
            let visit = existing.recordingVisit(score: score, at: date)
            try visit.save(db)
            return visit
        }
        await reload()
        return visit
    }

    func restore(_ visits: [HexVisit]) async throws {
        try await database.writer.write { db in
            for remote in visits {
                var merged = remote
                if let local = try HexVisit.fetchOne(db, key: remote.cell) {
                    merged.total = max(local.total, remote.total)
                    merged.score = max(local.score, remote.score)
                    if HexVisit.scoringCalendar.isDate(local.lastVisit, inSameDayAs: remote.lastVisit) {
                        merged.lastScore = max(local.lastScore, remote.lastScore)
                    } else if local.lastVisit > remote.lastVisit {
                        merged.lastScore = local.lastScore
                    }
                    merged.lastVisit = max(local.lastVisit, remote.lastVisit)
                }
                try merged.save(db)
            }
        }
        await reload()
    }

    func visit(for cell: HexCell) async throws -> HexVisit? {
        try await database.writer.read { db in
            try HexVisit.fetchOne(db, key: cell)
        }
    }

    func reload() async {
        do {
            let visits = try await database.writer.read { db in
                try HexVisit.fetchAll(db)
            }
            snapshot = HexOwnershipSnapshot(
                states: Dictionary(uniqueKeysWithValues: visits.map { ($0.cell, HexState.forScore($0.score)) })
            )
        } catch {
            Logger().error("HexVisitStore reload failed: \(error)")
        }
    }
}
