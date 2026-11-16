import Foundation
import GRDB

extension HexVisitLog: FetchableRecord, MutablePersistableRecord {
    static let databaseTableName = "hexVisitLog"

    nonisolated init(row: Row) {
        id = row["id"]
        timestamp = row["timestamp"]
        cell = row["hexId"]
        latitude = row["latitude"]
        longitude = row["longitude"]
        speed = row["speed"]
        score = row["score"]
    }

    nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["id"] = id
        container["timestamp"] = timestamp
        container["hexId"] = cell
        container["latitude"] = latitude
        container["longitude"] = longitude
        container["speed"] = speed
        container["score"] = score
    }

    nonisolated mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }
}
