import Foundation
import Observation

/// Drives the once-per-UTC-day "Common Daily Box". Hosts feed it the server's
/// `dailyRewardAvailableAt` via `update(availableAt:)` after loading the profile.
@Observable
@MainActor
final class DailyRewardViewModel {
    private let service: AuthenticatedService
    private let now: () -> Date
    private(set) var availableAt: Date?
    private(set) var isClaiming = false
    private(set) var errorMessage: String?
    var reward: PowerUpDefinition?

    init(service: AuthenticatedService, now: @escaping () -> Date = { Date() }) {
        self.service = service
        self.now = now
    }

    func update(availableAt: Date?) {
        self.availableAt = availableAt
    }

    func isAvailable(at date: Date) -> Bool {
        availableAt.map { $0 <= date } ?? false
    }

    /// Seconds until the next box, rounded up so the countdown never shows zero while locked.
    func remaining(at date: Date) -> Duration? {
        guard let availableAt, availableAt > date else { return nil }
        return .seconds(availableAt.timeIntervalSince(date).rounded(.up))
    }

    @discardableResult
    func claim() async -> AddPowerUpResponse? {
        guard !isClaiming else { return nil }
        isClaiming = true
        errorMessage = nil
        defer { isClaiming = false }
        do {
            let response = try await service.claimDailyReward()
            availableAt = Self.nextReset(after: now())
            reward = response.powerup
            return response
        } catch {
            // The server rejects repeat claims with a status ASKCore surfaces as a generic error,
            // so resync from the profile to tell "already claimed" apart from a real failure.
            if let summary = try? await service.fetchProfile(),
               let serverAvailableAt = summary.dailyRewardAvailableAt,
               serverAvailableAt > now() {
                availableAt = serverAvailableAt
            } else {
                errorMessage = "Couldn't open the daily box. Try again."
            }
            return nil
        }
    }

    /// The next 00:00 UTC strictly after `date`.
    static func nextReset(after date: Date) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date))!
    }
}
