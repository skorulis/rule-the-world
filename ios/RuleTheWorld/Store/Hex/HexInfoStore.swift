import Foundation
import GRDB
import OSLog
import Observation

@Observable
@MainActor
final class HexInfoStore {
    private(set) var snapshot = HexOwnershipSnapshot(states: [:])

    private let database: AppDatabase

    init(database: AppDatabase) {
        self.database = database
        Task {
            await reload()
        }
    }

    func recordVisit(_ cell: HexCell, score: Double = 1, at date: Date = .now) async throws -> HexVisit {
        let visit = try await database.writer.write { db in
            var info = try HexInfo.fetchOne(db, key: cell)
                ?? HexInfo(cell: cell, totals: nil, userVisit: nil)
            let previous = info.userVisit ?? HexVisit(lastVisit: .distantPast, score: 0, lastScore: 0)
            let visit = previous.recordingVisit(score: score, at: date)
            info.userVisit = visit
            if visit.total > previous.total {
                info.totals?.totalVisits += 1
            }
            try info.save(db)
            return visit
        }
        await reload()
        return visit
    }

    func restore(_ infos: [HexInfo]) async throws {
        try await database.writer.write { db in
            for remote in infos {
                let local = try HexInfo.fetchOne(db, key: remote.cell)
                try merged(remote: remote, local: local).save(db)
            }
        }
        await reload()
    }

    func save(_ info: HexInfo) async throws -> HexInfo {
        let merged = try await database.writer.write { db in
            let merged = merged(remote: info, local: try HexInfo.fetchOne(db, key: info.cell))
            try merged.save(db)
            return merged
        }
        await reload()
        return merged
    }

    func info(for cell: HexCell) async throws -> HexInfo? {
        try await database.writer.read { db in
            try HexInfo.fetchOne(db, key: cell)
        }
    }

    func infos(for cells: [HexCell]) async throws -> [HexInfo] {
        try await database.writer.read { db in
            try HexInfo.fetchAll(db, keys: cells)
        }
    }

    /// Optimistically adds `bonus` to the user's score on each cell so the map
    /// updates instantly. Returns the previous infos so callers can roll back
    /// if the server rejects the consume.
    @discardableResult
    func applyPowerUp(bonus: Double, to cells: [HexCell]) async throws -> [HexInfo] {
        let previous = try await database.writer.write { db in
            let previous = try HexInfo.fetchAll(db, keys: cells)
            for cell in cells {
                var info = try HexInfo.fetchOne(db, key: cell)
                    ?? HexInfo(cell: cell, totals: nil, userVisit: nil)
                var visit = info.userVisit ?? HexVisit(lastVisit: .distantPast, score: 0, lastScore: 0)
                visit.score += bonus
                info.userVisit = visit
                try info.save(db)
            }
            return previous
        }
        await reload()
        return previous
    }

    /// Undoes an optimistic `applyPowerUp`: writes the previous records back
    /// verbatim (no max-merge) and deletes records created for cells that had
    /// none before.
    func undoPowerUp(previous: [HexInfo], for cells: [HexCell]) async throws {
        try await database.writer.write { db in
            let restored = Set(previous.map(\.cell))
            for info in previous {
                try info.save(db)
            }
            for cell in cells where !restored.contains(cell) {
                try HexInfo.deleteOne(db, key: cell)
            }
        }
        await reload()
    }

    func staleCells(in cells: [HexCell], asOf date: Date = .now) async throws -> [HexCell] {
        let threshold = date.addingTimeInterval(-HexInfoRefreshPolicy.staleInterval)
        return try await database.writer.read { db in
            let fresh = Set(
                try HexInfo.fetchAll(db, keys: cells)
                    .compactMap { info in (info.lastUpdate ?? .distantPast) >= threshold ? info.cell : nil }
            )
            return cells.filter { !fresh.contains($0) }
        }
    }

    func visit(for cell: HexCell) async throws -> HexVisit? {
        try await info(for: cell)?.userVisit
    }

    func reload() async {
        do {
            let infos = try await database.writer.read { db in
                try HexInfo.fetchAll(db)
            }
            snapshot = HexOwnershipSnapshot(infos: infos)
        } catch {
            Logger().error("HexInfoStore reload failed: \(error)")
        }
    }

    private nonisolated func merged(remote: HexInfo, local: HexInfo?) -> HexInfo {
        var merged = remote
        guard let local else { return merged }
        merged.totals = remote.totals ?? local.totals
        merged.regions = remote.regions ?? local.regions
        merged.lastUpdate = remote.lastUpdate ?? local.lastUpdate
        switch (remote.userVisit, local.userVisit) {
        case (nil, let localVisit?):
            merged.userVisit = localVisit
        case (var remoteVisit?, let localVisit?):
            remoteVisit.total = max(localVisit.total, remoteVisit.total)
            remoteVisit.score = max(localVisit.score, remoteVisit.score)
            if HexVisit.scoringCalendar.isDate(localVisit.lastVisit, inSameDayAs: remoteVisit.lastVisit) {
                remoteVisit.lastScore = max(localVisit.lastScore, remoteVisit.lastScore)
            } else if localVisit.lastVisit > remoteVisit.lastVisit {
                remoteVisit.lastScore = localVisit.lastScore
            }
            remoteVisit.lastVisit = max(localVisit.lastVisit, remoteVisit.lastVisit)
            merged.userVisit = remoteVisit
        default:
            break
        }
        return merged
    }
}
