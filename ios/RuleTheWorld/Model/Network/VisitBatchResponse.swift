import Foundation

nonisolated struct VisitBatchResponse: Decodable {
    let acceptedIds: [String]
    let hexInfos: [HexInfo]
}
