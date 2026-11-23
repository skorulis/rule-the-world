import Foundation
import Observation

/// Drives the once-per-UTC-day coin stipend. Hosts feed it the server's
/// `stipendAvailableAt` and per-day `stipend` via `update(availableAt:amount:)`
/// after loading the profile.
@Observable
@MainActor
final class StipendViewModel {
    private let service: AuthenticatedService
    private let now: () -> Date
    private(set) var availableAt: Date?
    private(set) var amount: Int?
    private(set) var isCollecting = false
    private(set) var errorMessage: String?
    var collected: Int?

    init(service: AuthenticatedService, now: @escaping () -> Date = { Date() }) {
        self.service = service
        self.now = now
    }

    func update(availableAt: Date?, amount: Int?) {
        self.availableAt = availableAt
        self.amount = amount
    }

    func isAvailable(at date: Date) -> Bool {
        availableAt.map { $0 <= date } ?? false
    }

    /// Seconds until the next stipend, rounded up so the countdown never shows zero while locked.
    func remaining(at date: Date) -> Duration? {
        guard let availableAt, availableAt > date else { return nil }
        return .seconds(availableAt.timeIntervalSince(date).rounded(.up))
    }

    @discardableResult
    func collect() async -> StipendResponse? {
        guard !isCollecting else { return nil }
        isCollecting = true
        errorMessage = nil
        defer { isCollecting = false }
        do {
            let response = try await service.collectStipend()
            availableAt = DailyRewardViewModel.nextReset(after: now())
            collected = response.stipend
            return response
        } catch {
            // The server rejects repeat collections with a status ASKCore surfaces as a generic
            // error, so resync from the profile to tell "already collected" from a real failure.
            if let summary = try? await service.fetchProfile(),
               let serverAvailableAt = summary.stipendAvailableAt,
               serverAvailableAt > now() {
                availableAt = serverAvailableAt
            } else {
                errorMessage = "Couldn't collect your stipend. Try again."
            }
            return nil
        }
    }
}
