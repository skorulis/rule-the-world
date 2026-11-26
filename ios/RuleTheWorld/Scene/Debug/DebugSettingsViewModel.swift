import ASKCore
import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class DebugSettingsViewModel {
    var endpoint: NetworkEndpoint {
        didSet {
            guard endpoint != oldValue else { return }
            settings.endpoint = endpoint
            showRestartAlert = true
        }
    }
    var showRestartAlert = false
    private(set) var isAddingVisits = false
    private(set) var visitMessage: String?
    private(set) var isAddingPowerUp = false
    private(set) var powerUpMessage: String?
    private(set) var isAddingMoney = false
    private(set) var moneyMessage: String?

    private let settings = DebugSettings()
    private let locationService: LocationService
    private let captureService: LocationCaptureService
    private let service: AuthenticatedService
    private let notificationService: NotificationService

    @Resolvable<Resolver>
    init(
        locationService: LocationService,
        captureService: LocationCaptureService,
        service: AuthenticatedService,
        notificationService: NotificationService
    ) {
        self.locationService = locationService
        self.captureService = captureService
        self.service = service
        self.notificationService = notificationService
        self.endpoint = settings.endpoint
    }

    var canShowNotifications: Bool { notificationService.hasHost }

    func showSampleNotifications(queued: Bool) {
        guard canShowNotifications else { return }
        notificationService.show(AppNotification(title: "Exploration", message: "You discovered a new region"))
        guard queued else { return }
        notificationService.show(AppNotification(
            title: "New rank!",
            message: "You have gained the Burgess rank in Australia",
            icon: "rank-burgess",
            rarity: .common
        ))
        notificationService.show(AppNotification(
            title: "New rank!",
            message: "You have gained the Duke rank in Australia",
            icon: "rank-duke",
            rarity: .legendary
        ))
    }

    var hasLocation: Bool {
        locationService.latestSample != nil
    }

    var canAddVisits: Bool {
        hasLocation && !isAddingVisits
    }

    func addNearbyVisits() async {
        guard !isAddingVisits, let sample = locationService.latestSample else { return }
        isAddingVisits = true
        visitMessage = nil
        defer { isAddingVisits = false }
        do {
            try await captureService.addRandomNearbyVisits(near: sample.coordinate)
            visitMessage = "Added 5 visits and updated hex scores."
        } catch {
            visitMessage = error.localizedDescription
        }
    }

    func addPowerUp() async {
        guard !isAddingPowerUp else { return }
        isAddingPowerUp = true
        powerUpMessage = nil
        defer { isAddingPowerUp = false }
        do {
            let response = try await service.addPowerUp()
            powerUpMessage = "Granted \(response.powerup.displayName)."
        } catch {
            powerUpMessage = error.localizedDescription
        }
    }

    func addMoney() async {
        guard !isAddingMoney else { return }
        isAddingMoney = true
        moneyMessage = nil
        defer { isAddingMoney = false }
        do {
            let response = try await service.addMoney()
            if let coins = response.coins {
                moneyMessage = "Added \(response.added) coins. Balance: \(coins)."
            } else {
                moneyMessage = "Added \(response.added) coins."
            }
        } catch {
            moneyMessage = error.localizedDescription
        }
    }
}
