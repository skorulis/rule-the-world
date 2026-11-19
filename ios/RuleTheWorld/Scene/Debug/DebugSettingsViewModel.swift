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

    private let settings = DebugSettings()
    private let locationService: LocationService
    private let captureService: LocationCaptureService

    @Resolvable<Resolver>
    init(locationService: LocationService, captureService: LocationCaptureService) {
        self.locationService = locationService
        self.captureService = captureService
        self.endpoint = settings.endpoint
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
}
