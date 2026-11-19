import Foundation
import GRDB

final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
        try Self.makeMigrator().migrate(writer)
    }

    func erase() throws {
        try writer.erase()
        try Self.makeMigrator().migrate(writer)
    }

    private static func makeMigrator() -> DatabaseMigrator {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1 createHexVisit") { db in
            try db.create(table: "hexVisit") { table in
                table.column("hexId", .integer).primaryKey()
                table.column("lastVisit", .datetime).notNull()
                table.column("score", .double).notNull()
                table.column("lastScore", .double).notNull()
            }
        }
        migrator.registerMigration("v2 createHexVisitLog") { db in
            try db.create(table: "hexVisitLog") { table in
                table.autoIncrementedPrimaryKey("id")
                table.column("timestamp", .datetime).notNull()
                table.column("hexId", .integer).notNull().indexed()
                table.column("latitude", .double).notNull()
                table.column("longitude", .double).notNull()
                table.column("speed", .double)
                table.column("score", .double).notNull()
            }
        }
        migrator.registerMigration("v3 hexVisitLogLocationTypeAndCount") { db in
            try db.alter(table: "hexVisitLog") { table in
                table.add(column: "locationType", .text)
                    .notNull()
                    .defaults(to: LocationType.foreground.rawValue)
                table.add(column: "count", .integer)
                    .notNull()
                    .defaults(to: 1)
            }
        }
        return migrator
    }

    static func onDisk() throws -> AppDatabase {
        let directory = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("RuleTheWorld", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let pool = try DatabasePool(path: directory.appendingPathComponent("db.sqlite").path)
        return try AppDatabase(writer: pool)
    }

    static func inMemory() throws -> AppDatabase {
        try AppDatabase(writer: DatabaseQueue())
    }
}
