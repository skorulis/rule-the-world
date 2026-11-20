import Foundation

nonisolated struct VisitDownloadResponse: Decodable {
    let visits: [HexInfo]
}
