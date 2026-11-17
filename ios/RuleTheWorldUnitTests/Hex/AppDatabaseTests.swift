import GRDB
import CoreLocation
import Testing
@testable import RuleTheWorld

struct AppDatabaseTests {
    @Test func migrationCreatesHexVisitTable() throws {
        let database = try AppDatabase.inMemory()
        let exists = try database.writer.read { db in
            try db.tableExists("hexVisit")
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

    @Test func hexCellRoundTripsThroughDatabase() throws {
        let database = try AppDatabase.inMemory()
        let grid = HexGridService()
        let cell = grid.cell(
            containing: CLLocationCoordinate2D(latitude: -33.89, longitude: 151.19),
            resolution: HexGridService.baseResolution
        )
        try database.writer.write { db in
            let visit = HexVisit(cell: cell, lastVisit: .now, score: 1, lastScore: 1)
            try visit.save(db)
        }
        let fetched = try database.writer.read { db in
            try HexVisit.fetchOne(db, key: cell)
        }
        #expect(fetched?.cell == cell)
    }
}
