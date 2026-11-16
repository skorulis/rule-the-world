import Foundation

struct HexVisitLog: Hashable, Codable, Sendable {
    var id: Int64?
    var timestamp: Date
    var cell: HexCell
    var latitude: Double
    var longitude: Double
    var speed: Double?
    var score: Double

    nonisolated init(
        id: Int64? = nil,
        timestamp: Date,
        cell: HexCell,
        latitude: Double,
        longitude: Double,
        speed: Double?,
        score: Double
    ) {
        self.id = id
        self.timestamp = timestamp
        self.cell = cell
        self.latitude = latitude
        self.longitude = longitude
        self.speed = speed
        self.score = score
    }

    nonisolated init(sample: LocationSample, cell: HexCell, score: Double) {
        self.init(
            timestamp: sample.timestamp,
            cell: cell,
            latitude: sample.latitude,
            longitude: sample.longitude,
            speed: sample.speed,
            score: score
        )
    }

    nonisolated func merging(_ other: HexVisitLog) -> HexVisitLog {
        let winner: HexVisitLog
        if score != other.score {
            winner = score > other.score ? self : other
        } else {
            switch (speed, other.speed) {
            case let (own?, incoming?):
                winner = own < incoming ? self : other
            case (.some, nil):
                winner = self
            default:
                winner = other
            }
        }
        let mergedSpeed: Double?
        switch (speed, other.speed) {
        case let (own?, incoming?):
            mergedSpeed = min(own, incoming)
        case let (own?, nil):
            mergedSpeed = own
        case let (nil, incoming?):
            mergedSpeed = incoming
        case (nil, nil):
            mergedSpeed = nil
        }
        return HexVisitLog(
            id: id,
            timestamp: winner.timestamp,
            cell: cell,
            latitude: winner.latitude,
            longitude: winner.longitude,
            speed: mergedSpeed,
            score: max(score, other.score)
        )
    }
}
