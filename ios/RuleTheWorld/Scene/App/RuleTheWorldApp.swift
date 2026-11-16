import ASKCoordinator
import ASKCore
import Knit
import SwiftUI

@main
struct RuleTheWorldApp: App {
    private let assembler: ScopedModuleAssembler<Resolver> = {
        let assembler = ScopedModuleAssembler<Resolver>(
            [
                RuleTheWorldAssembly(purpose: .normal)
            ]
        )
        return assembler
    }()

    private let locationService: LocationService?
    private let captureService: LocationCaptureService?

    init() {
        guard !ProcessInfo.isRunningTests else {
            locationService = nil
            captureService = nil
            return
        }
        let locationService = assembler.resolver.locationService()
        let captureService = assembler.resolver.locationCaptureService()
        locationService.start()
        captureService.start(samples: locationService.samples)
        self.locationService = locationService
        self.captureService = captureService
    }

    var body: some Scene {
        WindowGroup {
            if ProcessInfo.isRunningTests {
                Color.clear
            } else {
                CoordinatorView(coordinator: Coordinator(root: MainPath.content))
                    .withRenderers(resolver: assembler.resolver)
                    .environment(\.resolver, assembler.resolver)
            }
        }
    }
}

private extension ProcessInfo {
    static var isRunningTests: Bool {
        processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
