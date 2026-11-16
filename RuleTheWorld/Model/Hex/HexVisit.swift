import Foundation

struct HexVisit: Hashable, Codable, Sendable {
    static let maxDailyScore: Double = 1

    var cell: HexCell
    var lastVisit: Date
    var score: Double
    var lastScore: Double

    nonisolated func recordingVisit(
        score visitScore: Double,
        at date: Date,
        calendar: Calendar = .current
    ) -> HexVisit {
        let clamped = min(max(visitScore, 0), Self.maxDailyScore)
        let scoredToday = calendar.isDate(lastVisit, inSameDayAs: date) ? lastScore : 0
        let gain = max(clamped - scoredToday, 0)
        return HexVisit(
            cell: cell,
            lastVisit: date,
            score: score + gain,
            lastScore: scoredToday + gain
        )
    }
}
