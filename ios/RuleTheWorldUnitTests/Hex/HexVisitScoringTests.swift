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

    @Test func totalCountsEveryVisitRegardlessOfScoreOrDay() {
        let initial = visit(lastVisit: .distantPast, score: 0, lastScore: 0)
        let first = initial.recordingVisit(score: 0.8, at: noon)
        let lower = first.recordingVisit(score: 0.2, at: noon.addingTimeInterval(60))
        let zero = lower.recordingVisit(score: 0, at: noon.addingTimeInterval(120))
        let nextDay = zero.recordingVisit(score: 0.5, at: noon.addingTimeInterval(86_400))
        #expect(first.total == 1)
        #expect(lower.total == 2)
        #expect(zero.total == 3)
        #expect(nextDay.total == 4)
        #expect(abs(nextDay.score - 1.3) < 0.000_001)
    }

    @Test func defaultScoringCalendarMatchesServerUTC() {
        let beforeMidnight = noon.addingTimeInterval(43_199)
        let existing = visit(lastVisit: beforeMidnight, score: 1, lastScore: 1)
        let updated = existing.recordingVisit(score: 1, at: beforeMidnight.addingTimeInterval(2))
        #expect(HexVisit.scoringCalendar.timeZone.secondsFromGMT() == 0)
        #expect(updated.score == 2)
    }

    @Test func localMidnightDoesNotResetScoreWithinUTCDay() throws {
        let formatter = ISO8601DateFormatter()
        let before = try #require(formatter.date(from: "2026-11-20T23:59:59-08:00"))
        let after = try #require(formatter.date(from: "2026-11-21T00:00:01-08:00"))
        let existing = visit(lastVisit: before, score: 1, lastScore: 1)
        let updated = existing.recordingVisit(score: 1, at: after)
        #expect(updated.score == 1)
        #expect(updated.total == 1)
    }

    @Test func justBeforeMidnightAndJustAfterAreDifferentDays() {
        let beforeMidnight = noon.addingTimeInterval(43_199)
        let existing = visit(lastVisit: beforeMidnight, score: 1, lastScore: 1)
        let updated = existing.recordingVisit(score: 1, at: beforeMidnight.addingTimeInterval(2), calendar: calendar)
        #expect(abs(updated.score - 2) < 0.000_001)
    }
}
