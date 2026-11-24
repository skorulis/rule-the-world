import Foundation

extension HexVisit {
    private enum CodingKeys: String, CodingKey {
        case lastVisit, score, lastScore, total
    }

    nonisolated init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let dateString = try container.decode(String.self, forKey: .lastVisit)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .lastVisit, in: container, debugDescription: "Invalid ISO 8601 date"
            )
        }
        lastVisit = date
        score = try container.decode(Double.self, forKey: .score)
        lastScore = try container.decode(Double.self, forKey: .lastScore)
        total = try container.decode(Int.self, forKey: .total)
        guard total >= 0, score.isFinite, score >= 0,
              lastScore.isFinite, (0...Self.maxDailyScore).contains(lastScore) else {
            throw DecodingError.dataCorrupted(.init(
                codingPath: decoder.codingPath, debugDescription: "Invalid visit totals or scores"
            ))
        }
    }

    nonisolated func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        try container.encode(formatter.string(from: lastVisit), forKey: .lastVisit)
        try container.encode(score, forKey: .score)
        try container.encode(lastScore, forKey: .lastScore)
        try container.encode(total, forKey: .total)
    }
}

struct HexVisit: Hashable, Codable, Sendable {
    nonisolated static let maxDailyScore: Double = 1
    nonisolated static var scoringCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }

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
        let sameDay = calendar.isDate(lastVisit, inSameDayAs: date)
        let scoredToday = sameDay ? lastScore : 0
        let gain = max(clamped - scoredToday, 0)
        return HexVisit(
            lastVisit: date,
            score: score + gain,
            lastScore: scoredToday + gain,
            total: total + (sameDay ? 0 : 1)
        )
    }
}
