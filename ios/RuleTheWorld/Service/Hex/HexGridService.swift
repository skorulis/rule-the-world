import CoreLocation
import MapKit
import SwiftyH3

nonisolated final class HexGridService: Sendable {
    static let baseResolution = 10

    init() {}

    func cell(containing coordinate: CLLocationCoordinate2D, resolution: Int) -> HexCell {
        let res = H3Cell.Resolution(rawValue: Int32(resolution)) ?? .res9
        guard let cell = try? coordinate.h3LatLng.cell(at: res) else {
            return HexCell(rawValue: 0)
        }
        return HexCell(rawValue: cell.id)
    }

    func boundary(of cell: HexCell) -> [CLLocationCoordinate2D] {
        let h3Cell = H3Cell(cell.rawValue)
        return (try? h3Cell.boundary)?.map { $0.coordinates } ?? []
    }

    func cells(in region: MKCoordinateRegion, resolution: Int) -> [HexCell] {
        let res = H3Cell.Resolution(rawValue: Int32(resolution)) ?? .res9
        let center = region.center
        let span = region.span
        let minLat = max(center.latitude - span.latitudeDelta / 2, -85)
        let maxLat = min(center.latitude + span.latitudeDelta / 2, 85)
        let minLon = max(center.longitude - span.longitudeDelta / 2, -180)
        let maxLon = min(center.longitude + span.longitudeDelta / 2, 180)
        let corners = [
            H3LatLng(latitudeDegs: minLat, longitudeDegs: minLon),
            H3LatLng(latitudeDegs: minLat, longitudeDegs: maxLon),
            H3LatLng(latitudeDegs: maxLat, longitudeDegs: maxLon),
            H3LatLng(latitudeDegs: maxLat, longitudeDegs: minLon)
        ]
        let polygon = H3Polygon(corners)
        let cells = (try? polygon.cellsExperimental(at: res, containmentType: .overlapping)) ?? []
        return cells.map { HexCell(rawValue: $0.id) }
    }

    func parent(of cell: HexCell, at resolution: Int) -> HexCell? {
        let res = H3Cell.Resolution(rawValue: Int32(resolution)) ?? .res9
        guard let parent = try? H3Cell(cell.rawValue).parent(at: res) else {
            return nil
        }
        return HexCell(rawValue: parent.id)
    }

    func children(of cell: HexCell, at resolution: Int) -> [HexCell] {
        let res = H3Cell.Resolution(rawValue: Int32(resolution)) ?? .res9
        guard let children = try? H3Cell(cell.rawValue).children(at: res) else {
            return []
        }
        return children.map { HexCell(rawValue: $0.id) }
    }
}
