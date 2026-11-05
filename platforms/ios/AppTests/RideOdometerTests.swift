import Foundation
import MotoNavigationCore
import XCTest
@testable import MOTO_GPS

final class RideOdometerTests: XCTestCase {
    private func fix(_ seconds: Double, latitude: Double = 22.54, speed: Double? = 5, accuracy: Double = 5) -> NavigationFix {
        NavigationFix(coordinate: WGS84Point(longitudeDeg: 114.05, latitudeDeg: latitude),
                      horizontalAccuracyM: accuracy, speedMps: speed,
                      timestamp: Date(timeIntervalSince1970: 1_000 + seconds))
    }

    func testDistancePersistsAndNewRideDoesNotConnectToPreviousRide() throws {
        let name = "QianGPS.OdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = RideOdometer(defaults: defaults)
        store.record(fix(0))
        store.record(fix(2, latitude: 22.5401))
        XCTAssertEqual(store.totalDistanceM, 11.1, accuracy: 0.2)
        XCTAssertEqual(RideOdometer(defaults: defaults).totalDistanceM, store.totalDistanceM)
        let saved = store.totalDistanceM
        store.resetSegment()
        store.record(fix(3, latitude: 22.541))
        XCTAssertEqual(store.totalDistanceM, saved)
    }

    func testStationaryDriftPoorAccuracyDuplicatesGapsAndJumpsDoNotCount() throws {
        let name = "QianGPS.OdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = RideOdometer(defaults: defaults)
        store.record(fix(0))
        store.record(fix(1, latitude: 22.5401, speed: 0))
        store.record(fix(2)) // new anchor after stopping
        store.record(fix(2, latitude: 23)) // duplicate
        store.record(fix(1, latitude: 23)) // out of order
        store.record(fix(3, latitude: 23, accuracy: 100))
        store.record(fix(4)) // new anchor after poor accuracy
        store.record(fix(40, latitude: 22.541)) // location gap
        store.record(fix(41, latitude: 23)) // impossible jump
        XCTAssertEqual(store.totalDistanceM, 0)
    }
}
