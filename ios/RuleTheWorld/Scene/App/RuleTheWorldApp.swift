import ASKCoordinator
import ASKCore
import Knit
import SwiftUI

@main
struct RuleTheWorldApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var signedOutCoordinator = Coordinator(root: MainPath.signedOut)
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
    private let backgroundSyncScheduler: BackgroundVisitSyncScheduler?

    private var shouldSyncVisits: Bool {
        scenePhase == .active && authManager?.isSignedIn == true
    }

    init() {
        guard !ProcessInfo.isRunningTests else {
            locationService = nil
            captureService = nil
            authManager = nil
            visitSyncService = nil
            backgroundSyncScheduler = nil
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
        self.backgroundSyncScheduler = assembler.resolver.backgroundVisitSyncScheduler()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if ProcessInfo.isRunningTests {
                    Color.clear
                } else if let authManager, authManager.isSignedIn {
                    if authManager.needsBannerSetup {
                        BannerSetupView { authManager.completeBannerSetup() }
                            .environment(\.resolver, assembler.resolver)
                    } else if let locationService, !locationService.hasLocationAccess {
                        LocationPermissionView(locationService: locationService)
                    } else {
                        ContentView(model: ContentViewModel.make(resolver: assembler.resolver))
                            .environment(\.resolver, assembler.resolver)
                    }
                } else {
                    CoordinatorView(coordinator: signedOutCoordinator)
                        .withRenderers(resolver: assembler.resolver)
                        .environment(\.resolver, assembler.resolver)
                }
            }
            .debugMenu(resolver: assembler.resolver)
            .task(id: shouldSyncVisits) {
                guard shouldSyncVisits else { return }
                await visitSyncService?.run()
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .background else { return }
                Task { await backgroundSyncScheduler?.appDidEnterBackground() }
            }
        }
        .backgroundTask(.appRefresh(BackgroundVisitSyncScheduler.refreshTaskIdentifier)) { [backgroundSyncScheduler] in
            await backgroundSyncScheduler?.performRefresh()
        }
    }
}

private extension ProcessInfo {
    static var isRunningTests: Bool {
        processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
