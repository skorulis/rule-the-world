import CoreLocation

struct HexTile: Identifiable {
    let cell: HexCell
    let boundary: [CLLocationCoordinate2D]
    let state: HexState

    var id: UInt64 { cell.id }
}
