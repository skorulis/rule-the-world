import Foundation

struct HexVisit: Hashable, Codable, Sendable {
    nonisolated static let maxDailyScore: Double = 1
    nonisolated static var scoringCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

    var cell: HexCell
    var lastVisit: Date
    var score: Double
    var lastScore: Double
    var total: Int = 0

    nonisolated func recordingVisit(
        score visitScore: Double,
        at date: Date,
        calendar: Calendar = HexVisit.scoringCalendar
    ) -> HexVisit {
        let clamped = min(max(visitScore, 0), Self.maxDailyScore)
        let scoredToday = calendar.isDate(lastVisit, inSameDayAs: date) ? lastScore : 0
        let gain = max(clamped - scoredToday, 0)
        return HexVisit(
            cell: cell,
            lastVisit: date,
            score: score + gain,
            lastScore: scoredToday + gain,
            total: total + 1
        )
    }
}
