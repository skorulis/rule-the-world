import GRDB
import CoreLocation
import Testing
@testable import RuleTheWorld

struct AppDatabaseTests {
    @Test func migrationCreatesHexInfoTable() throws {
        let database = try AppDatabase.inMemory()
        let exists = try database.writer.read { db in
            try db.tableExists("hexInfo")
        }
        #expect(exists)
    }

    @Test func migrationCreatesHexVisitLogTable() throws {
        let database = try AppDatabase.inMemory()
        let exists = try database.writer.read { db in
            try db.tableExists("hexVisitLog")
        }
        #expect(exists)
    }

    @Test func migrationAddsLocationTypeAndCountColumns() throws {
        let database = try AppDatabase.inMemory()
        let columns = try database.writer.read { db in
            try db.columns(in: "hexVisitLog").map(\.name)
        }
        #expect(columns.contains("locationType"))
        #expect(columns.contains("count"))
    }

    @Test func uploadMigrationBackfillsExistingLogs() throws {
        let writer = try DatabaseQueue()
        var legacy = DatabaseMigrator()
        legacy.registerMigration("v1 createHexVisit") { db in
            try db.execute(sql: """
                CREATE TABLE hexVisit (hexId INTEGER PRIMARY KEY, lastVisit DATETIME NOT NULL,
                    score DOUBLE NOT NULL, lastScore DOUBLE NOT NULL)
                """)
        }
        legacy.registerMigration("v2 createHexVisitLog") { db in
            try db.execute(sql: """
                CREATE TABLE hexVisitLog (id INTEGER PRIMARY KEY AUTOINCREMENT, timestamp DATETIME NOT NULL,
                    hexId INTEGER NOT NULL, latitude DOUBLE NOT NULL, longitude DOUBLE NOT NULL,
                    speed DOUBLE, score DOUBLE NOT NULL)
                """)
        }
        legacy.registerMigration("v3 hexVisitLogLocationTypeAndCount") { db in
            try db.execute(sql: """
                ALTER TABLE hexVisitLog ADD COLUMN locationType TEXT NOT NULL DEFAULT 'foreground';
                ALTER TABLE hexVisitLog ADD COLUMN count INTEGER NOT NULL DEFAULT 1;
                INSERT INTO hexVisitLog (timestamp, hexId, latitude, longitude, score)
                    VALUES ('2026-11-20 10:00:00', 1, 0, 0, 1), ('2026-11-20 11:00:00', 2, 0, 0, 0.5);
                UPDATE hexVisitLog SET count = 4 WHERE hexId = 1;
                INSERT INTO hexVisit (hexId, lastVisit, score, lastScore)
                    VALUES (1, '2026-11-20 10:00:00', 1, 1), (3, '2026-11-20 10:00:00', 1, 1)
                """)
        }
        try legacy.migrate(writer)
        let database = try AppDatabase(writer: writer)
        let entries = try database.writer.read { db in try HexVisitLog.fetchAll(db) }
        #expect(entries.count == 2)
        #expect(entries.allSatisfy { !$0.uploaded && !$0.uploadID.isEmpty })
        #expect(Set(entries.map(\.uploadID)).count == 2)
        let legacyTableDropped = try database.writer.read { db in
            try !db.tableExists("hexVisit") && db.tableExists("hexInfo")
        }
        #expect(legacyTableDropped)
    }

    @Test func hexCellRoundTripsThroughDatabase() throws {
        let database = try AppDatabase.inMemory()
        let grid = HexGridService()
        let cell = grid.cell(
            containing: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            resolution: HexGridService.baseResolution
        )
        try database.writer.write { db in
            let info = HexInfo(
                cell: cell, totals: HexTotals(totalVisits: 12, rivalScore: 3.5),
                userVisit: HexVisit(lastVisit: .now, score: 1, lastScore: 1, total: 7)
            )
            try info.save(db)
        }
        let fetched = try database.writer.read { db in
            try HexInfo.fetchOne(db, key: cell)
        }
        #expect(fetched?.cell == cell)
        #expect(fetched?.totals?.totalVisits == 12)
        #expect(fetched?.totals?.rivalScore == 3.5)
        #expect(fetched?.userVisit?.total == 7)
    }
}
