import Foundation
import GRDB

@MainActor
final class HexVisitLogStore {
    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
    }

    func record(_ entry: HexVisitLog) async throws -> HexVisitLog {
        try await database.writer.write { db in
            let last = try HexVisitLog.order(Column("id").desc).fetchOne(db)
            if last?.cell == entry.cell, var merged = last?.merging(entry) {
                try merged.update(db)
                return merged
            }
            var new = entry
            new.id = nil
            try new.insert(db)
            return new
        }
    }

    func latest() async throws -> HexVisitLog? {
        try await database.writer.read { db in
            try HexVisitLog.order(Column("id").desc).fetchOne(db)
        }
    }

    func all() async throws -> [HexVisitLog] {
        try await database.writer.read { db in
            try HexVisitLog.order(Column("id").asc).fetchAll(db)
        }
    }
}
