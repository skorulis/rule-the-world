import MapKit

enum HexZoomPolicy {
    // Average hexagon area in square metres, indexed by H3 resolution.
    private static let averageHexagonAreaM2: [Double] = [
        4_357_449_416_078.4, 609_788_441_794.1, 86_801_179_039.0, 12_393_434_655.1,
        1_770_347_654.5, 252_903_858.2, 36_129_062.2, 5_161_293.4,
        737_327.6, 105_332.5, 15_047.5, 2_149.6,
        307.1, 43.9, 6.3, 0.9,
    ]

    static func resolution(
        for region: MKCoordinateRegion,
        budget: Int = 400,
        baseResolution: Int = HexOwnershipStore.baseResolution,
        minResolution: Int = 4
    ) -> Int? {
        let latMeters = region.span.latitudeDelta * 111_000
        let lonMeters = region.span.longitudeDelta * 111_000 * cos(region.center.latitude * .pi / 180)
        let area = latMeters * lonMeters

        var res = baseResolution
        while res >= minResolution {
            if area / averageHexagonAreaM2[res] <= Double(budget) {
                return res
            }
            res -= 1
        }
        return nil
    }
}
