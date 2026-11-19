import ASKCoordinator
import ASKCore
import Knit
import SwiftUI

@main
struct RuleTheWorldApp: App {
    @Environment(\.scenePhase) private var scenePhase
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
    private let visitSyncService: HexVisitSyncService?

    private var shouldSyncVisits: Bool {
        scenePhase == .active && authManager?.isSignedIn == true
    }

    init() {
        guard !ProcessInfo.isRunningTests else {
            locationService = nil
            captureService = nil
            authManager = nil
            visitSyncService = nil
            return
        }
        let locationService = assembler.resolver.locationService()
        let captureService = assembler.resolver.locationCaptureService()
        locationService.start()
        captureService.start(samples: locationService.samples)
        self.locationService = locationService
        self.captureService = captureService
        self.authManager = assembler.resolver.authManager()
        self.visitSyncService = assembler.resolver.hexVisitSyncService()
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
            .debugMenu(resolver: assembler.resolver)
            .task(id: shouldSyncVisits) {
                guard shouldSyncVisits else { return }
                await visitSyncService?.run()
            }
        }
    }
}

private extension ProcessInfo {
    static var isRunningTests: Bool {
        processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
