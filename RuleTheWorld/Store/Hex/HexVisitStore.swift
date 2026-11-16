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
            var visit = try HexVisit.fetchOne(db, key: cell)
                ?? HexVisit(cell: cell, lastVisit: date, score: 0, lastScore: 0)
            visit.lastVisit = date
            visit.lastScore = score
            visit.score += score
            try visit.save(db)
            return visit
        }
        await reload()
        return visit
    }

    func visit(for cell: HexCell) async throws -> HexVisit? {
        try await database.writer.read { db in
            try HexVisit.fetchOne(db, key: cell)
        }
    }

    func reload() async {
        do {
            let cells = try await database.writer.read { db in
                try HexVisit.select(Column("hexId"), as: HexCell.self).fetchAll(db)
            }
            snapshot = HexOwnershipSnapshot(
                states: Dictionary(uniqueKeysWithValues: cells.map { ($0, HexState.mine) })
            )
        } catch {
            Logger().error("HexVisitStore reload failed: \(error)")
        }
    }
}
