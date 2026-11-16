import Foundation
import GRDB

final class AppDatabase: Sendable {
    let writer: any DatabaseWriter

    init(writer: any DatabaseWriter) throws {
        self.writer = writer
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
        try migrator.migrate(writer)
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
