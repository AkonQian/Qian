import CoreLocation
import Foundation
import MotoNavigationCore

/// Lifetime distance from real navigation fixes. Demo fixes never enter this store.
/// Break the segment at stops, poor fixes and gaps so reconnects cannot add a jump.
final class RideOdometer {
    private static let key = "QianGPS.TotalRideDistanceM.v1"
    private let defaults: UserDefaults
    private var previous: NavigationFix?
    private(set) var totalDistanceM: Double

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.double(forKey: Self.key)
        totalDistanceM = saved.isFinite && saved >= 0 ? saved : 0
    }

    func resetSegment() { previous = nil }

    func record(_ fix: NavigationFix) {
        // Duplicate or out-of-order callbacks must not replace a newer anchor.
        if let previous, fix.timestamp <= previous.timestamp { return }
        guard fix.coordinate.isValid, fix.horizontalAccuracyM.isFinite,
              (0...30).contains(fix.horizontalAccuracyM),
              let speed = fix.speedMps, speed.isFinite, (0.8...65).contains(speed)
        else { resetSegment(); return }
        defer { previous = fix }
        guard let previous else { return }
        let interval = fix.timestamp.timeIntervalSince(previous.timestamp)
        guard interval > 0, interval <= 15 else { return }
        let start = CLLocation(latitude: previous.coordinate.latitudeDeg, longitude: previous.coordinate.longitudeDeg)
        let end = CLLocation(latitude: fix.coordinate.latitudeDeg, longitude: fix.coordinate.longitudeDeg)
        let distance = end.distance(from: start)
        let plausibleSpeed = min(65, max(15, max(speed, previous.speedMps ?? speed) * 2 + 5))
        guard distance.isFinite, distance > 0, distance / interval <= plausibleSpeed else { return }
        totalDistanceM += distance
        defaults.set(totalDistanceM, forKey: Self.key)
    }
}
