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
            if let last, last.cell == entry.cell, !last.uploaded,
               HexVisit.scoringCalendar.isDate(last.timestamp, inSameDayAs: entry.timestamp) {
                var merged = last.merging(entry)
                try merged.update(db)
                return merged
            }
            var new = entry
            new.id = nil
            new.uploadID = UUID().uuidString
            new.uploaded = false
            try new.insert(db)
            return new
        }
    }

    func pending(after id: Int64 = 0, through lastID: Int64 = .max, limit: Int = 500) async throws -> [HexVisitLog] {
        try await database.writer.read { db in
            try HexVisitLog.filter(Column("uploaded") == false)
                .filter(Column("id") > id && Column("id") <= lastID)
                .order(Column("id").asc).limit(limit).fetchAll(db)
        }
    }

    func markUploaded(_ entries: [HexVisitLog], acceptedIDs: Set<String>) async throws {
        try await database.writer.write { db in
            for entry in entries where acceptedIDs.contains(entry.uploadID) {
                _ = try HexVisitLog.filter(Column("uploadID") == entry.uploadID && Column("count") == entry.count)
                    .updateAll(db, Column("uploaded").set(to: true))
            }
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
