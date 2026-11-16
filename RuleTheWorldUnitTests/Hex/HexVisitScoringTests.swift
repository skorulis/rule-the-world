import Foundation
import Testing
@testable import RuleTheWorld

struct HexVisitScoringTests {
    private let cell = HexCell(rawValue: 0x8A283082876FFFF)
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }
    private let noon = Date(timeIntervalSince1970: TimeInterval(1_700_000_000 - 1_700_000_000 % 86_400 + 43_200))

    private func visit(lastVisit: Date, score: Double, lastScore: Double) -> HexVisit {
        HexVisit(cell: cell, lastVisit: lastVisit, score: score, lastScore: lastScore)
    }

    @Test func partialVisitSameDayAddsOnlyTheDifference() {
        let existing = visit(lastVisit: noon, score: 5.3, lastScore: 0.3)
        let updated = existing.recordingVisit(score: 0.8, at: noon.addingTimeInterval(3_600), calendar: calendar)
        #expect(abs(updated.score - 5.8) < 0.000_001)
        #expect(abs(updated.lastScore - 0.8) < 0.000_001)
    }

    @Test func lowerVisitSameDayAddsNothing() {
        let existing = visit(lastVisit: noon, score: 5.8, lastScore: 0.8)
        let updated = existing.recordingVisit(score: 0.2, at: noon.addingTimeInterval(3_600), calendar: calendar)
        #expect(abs(updated.score - 5.8) < 0.000_001)
        #expect(abs(updated.lastScore - 0.8) < 0.000_001)
        #expect(updated.lastVisit == noon.addingTimeInterval(3_600))
    }

    @Test func previousDayScoreIsTreatedAsZero() {
        let existing = visit(lastVisit: noon, score: 5.8, lastScore: 0.8)
        let updated = existing.recordingVisit(score: 0.4, at: noon.addingTimeInterval(86_400), calendar: calendar)
        #expect(abs(updated.score - 6.2) < 0.000_001)
        #expect(abs(updated.lastScore - 0.4) < 0.000_001)
    }

    @Test func visitScoreIsClampedToDailyMaximum() {
        let existing = visit(lastVisit: .distantPast, score: 0, lastScore: 0)
        let updated = existing.recordingVisit(score: 3, at: noon, calendar: calendar)
        #expect(abs(updated.score - 1) < 0.000_001)
        #expect(abs(updated.lastScore - 1) < 0.000_001)
    }

    @Test func justBeforeMidnightAndJustAfterAreDifferentDays() {
        let beforeMidnight = noon.addingTimeInterval(43_199)
        let existing = visit(lastVisit: beforeMidnight, score: 1, lastScore: 1)
        let updated = existing.recordingVisit(score: 1, at: beforeMidnight.addingTimeInterval(2), calendar: calendar)
        #expect(abs(updated.score - 2) < 0.000_001)
    }
}
