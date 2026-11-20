import Foundation
import GRDB

extension HexInfo: FetchableRecord, PersistableRecord {
    static let databaseTableName = "hexInfo"

    nonisolated init(row: Row) {
        let cell: HexCell = row["hexId"]
        let data: Data = row["json"]
        self = (try? JSONDecoder().decode(HexInfo.self, from: data))
            ?? HexInfo(cell: cell, totals: nil, userVisit: nil)
    }

    nonisolated func encode(to container: inout PersistenceContainer) throws {
        container["hexId"] = cell
        container["json"] = try JSONEncoder().encode(self)
    }
}
