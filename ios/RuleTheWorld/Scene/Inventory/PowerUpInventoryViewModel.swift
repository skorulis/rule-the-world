import Foundation
import Knit
import KnitMacros
import Observation

@Observable
@MainActor
final class PowerUpInventoryViewModel {
    struct Item: Identifiable {
        let id: Int
        let definition: PowerUpDefinition
        let count: Int

        var name: String { definition.displayName }
        var rarity: Rarity { definition.rarity }
        var detail: String { definition.formattedDescription }
    }

    private let service: AuthenticatedService
    private let profileService: ProfileService
    private let catalog: PowerUpCatalog
    private let store: HexInfoStore
    private(set) var items: [Item] = []
    private(set) var isConsuming = false
    private(set) var message: String?
    var selectedItemID: Int?
    private(set) var activationID = UUID()
    private(set) var activatedItemID: Int?
    private(set) var mapEffect: PowerUpEffect?
    private var showsMapEffects = true

    func setMapEffectsVisible(_ visible: Bool) {
        showsMapEffects = visible
        if !visible { mapEffect = nil }
    }

    var selectedItem: Item? {
        items.first { $0.id == selectedItemID }
    }

    func consumeSelected() async {
        guard let item = selectedItem else { return }
        await consume(item: item)
    }

    private func reconcileInventory(_ powerups: [String: Int]) {
        items = items.compactMap { entry in
            let count = powerups[String(entry.id)] ?? 0
            return count > 0 ? Item(id: entry.id, definition: entry.definition, count: count) : nil
        }
        reconcileSelection()
    }

    private func reconcileSelection() {
        if selectedItem == nil { selectedItemID = nil }
    }

    /// Supplies the base-resolution cells covering the map's visible window, or
    /// nil when the map isn't showing individual hexes. Wired by the map view.
    var mapWindowProvider: () -> [HexCell]? = { nil }

    /// Whether the map is at base hex resolution, kept in sync by the map view
    /// so `canUse` stays observable while this sheet is presented.
    var mapIsAtHexResolution = false

    @Resolvable<Resolver>
    init(
        service: AuthenticatedService,
        profileService: ProfileService,
        catalog: PowerUpCatalog,
        store: HexInfoStore
    ) {
        self.service = service
        self.profileService = profileService
        self.catalog = catalog
        self.store = store
    }

    var totalCount: Int {
        items.reduce(0) { $0 + $1.count }
    }

    /// Power-ups target hexes in the visible window, so they only work while
    /// the map shows base-resolution hexes.
    var canUse: Bool {
        mapIsAtHexResolution && mapWindowProvider() != nil
    }

    func load() async {
        if items.isEmpty, let cached = profileService.cachedSummary {
            apply(cached)
        }
        guard let summary = try? await profileService.fetchProfile(), !Task.isCancelled else { return }
        apply(summary)
    }

    private func apply(_ summary: ProfileSummary) {
        items = summary.powerups
            .compactMap { id, count in
                guard count > 0, let definition = catalog.definition(for: id) else { return nil }
                return Item(id: id, definition: definition, count: count)
            }
            .sorted { $0.rarity != $1.rarity
                ? $0.rarity < $1.rarity
                : $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        reconcileSelection()
    }

    /// Cells in `window` eligible for `type`, based on locally cached hex info.
    private func viableCells(in window: [HexCell], for type: PowerUpType, infos: [HexCell: HexInfo]) -> [HexCell] {
        window.filter { cell in
            let info = infos[cell]
            let userScore = info?.userVisit?.score ?? 0
            let rivalScore = info?.totals?.rivalScore ?? 0
            switch type {
            case .attack:
                return rivalScore > 0 && rivalScore >= userScore
            case .defend:
                return userScore > 0 && userScore > rivalScore
            case .explore:
                return (info?.userVisit?.total ?? 0) == 0
            }
        }
    }

    func consume(item: Item) async {
        guard !isConsuming,
              let item = items.first(where: { $0.id == item.id }), item.count > 0 else { return }
        message = nil
        guard mapIsAtHexResolution, let window = mapWindowProvider() else {
            message = "Zoom in until hexes appear to use power-ups."
            return
        }
        isConsuming = true
        defer {
            isConsuming = false
            if mapEffect?.phase == .pending { mapEffect = nil }
        }
        do {
            let infos = try await store.infos(for: window)
            let viable = viableCells(
                in: window, for: item.definition.type,
                infos: Dictionary(infos.map { ($0.cell, $0) }, uniquingKeysWith: { first, _ in first })
            )
            let targets = Array(viable.shuffled().prefix(item.definition.squares))
            guard !targets.isEmpty else {
                message = "No viable squares in view — \(item.name) was not used."
                return
            }
            try Task.checkCancellation()
            let effect = PowerUpEffect(
                id: UUID(), type: item.definition.type, rarity: item.rarity,
                bonus: item.definition.bonus, cells: targets, startedAt: .now
            )
            if showsMapEffects { mapEffect = effect }
            let previous = try await store.applyPowerUp(bonus: Double(item.definition.bonus), to: targets)
            do {
                let response = try await service.consumePowerUp(id: item.id, cells: targets)
                guard !Task.isCancelled else { return }
                try await store.restore(response.visits)
                reconcileInventory(response.powerups)
                if showsMapEffects && mapEffect?.id == effect.id && !Task.isCancelled {
                    mapEffect = effect.confirmed()
                }
                activatedItemID = item.id
                activationID = UUID()
                message = "\(item.name) applied to \(targets.count) \(targets.count == 1 ? "square" : "squares")."
            } catch {
                try? await store.undoPowerUp(previous: previous, for: targets)
                throw error
            }
        } catch let error as ConsumePowerUpFailure {
            message = error.error
        } catch {
            message = "Couldn't use \(item.name)."
        }
    }
}
