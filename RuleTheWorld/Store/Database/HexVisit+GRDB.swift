import Foundation
import GRDB

extension HexVisit: FetchableRecord, PersistableRecord {
    static let databaseTableName = "hexVisit"

    nonisolated init(row: Row) {
        cell = row["hexId"]
        lastVisit = row["lastVisit"]
        score = row["score"]
        lastScore = row["lastScore"]
    }

    nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["hexId"] = cell
        container["lastVisit"] = lastVisit
        container["score"] = score
        container["lastScore"] = lastScore
    }
}
