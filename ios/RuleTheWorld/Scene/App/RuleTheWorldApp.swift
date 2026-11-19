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
    private let authManager: AuthManager?

    init() {
        guard !ProcessInfo.isRunningTests else {
            locationService = nil
            captureService = nil
            authManager = nil
            return
        }
        let locationService = assembler.resolver.locationService()
        let captureService = assembler.resolver.locationCaptureService()
        locationService.start()
        captureService.start(samples: locationService.samples)
        self.locationService = locationService
        self.captureService = captureService
        self.authManager = assembler.resolver.authManager()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.isRunningTests {
                    Color.clear
                } else if let authManager, authManager.isSignedIn {
                    CoordinatorView(coordinator: Coordinator(root: MainPath.content))
                        .withRenderers(resolver: assembler.resolver)
                        .environment(\.resolver, assembler.resolver)
                } else {
                    LoginView(model: LoginViewModel.make(resolver: assembler.resolver))
                }
            }
            .debugMenu(locationService: locationService, captureService: captureService)
        }
    }
}

private extension ProcessInfo {
    static var isRunningTests: Bool {
        processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
