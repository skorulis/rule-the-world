import Foundation
import GRDB

extension HexCell: DatabaseValueConvertible {
    nonisolated var databaseValue: DatabaseValue {
        Int64(bitPattern: rawValue).databaseValue
    }

    nonisolated static func fromDatabaseValue(_ dbValue: DatabaseValue) -> HexCell? {
        guard let int64 = Int64.fromDatabaseValue(dbValue) else {
            return nil
        }
        return HexCell(rawValue: UInt64(bitPattern: int64))
    }
}
