import Foundation

enum VisitScorePolicy {
    static let maxHorizontalAccuracy = 100.0

    static func score(forSpeed speed: Double?) -> Double {
        guard let speed else { return 1 }
        let kmh = speed * 3.6
        if kmh < 20 { return 1 }
        if kmh < 50 { return 0.5 }
        if kmh < 150 { return 0.25 }
        return 0
    }

    static func isAcceptable(_ sample: LocationSample) -> Bool {
        (0 ... maxHorizontalAccuracy).contains(sample.horizontalAccuracy)
    }
}
