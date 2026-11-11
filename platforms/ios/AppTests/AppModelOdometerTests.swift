import Foundation
import MotoNavigationCore
import UIKit
import XCTest
@testable import MOTO_GPS

final class AppModelOdometerTests: XCTestCase {
    private func fix(_ seconds: Double, _ latitude: Double) -> NavigationFix {
        NavigationFix(coordinate: WGS84Point(longitudeDeg: 114.05, latitudeDeg: latitude),
                      horizontalAccuracyM: 5, speedMps: 5,
                      timestamp: Date(timeIntervalSince1970: 1_000 + seconds))
    }

    @MainActor func testIdleAndBackgroundFixesAccumulateWithoutRouteOrConnectedDisplay() throws {
        let name = "QianGPS.ModelOdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(odometer: RideOdometer(defaults: defaults), startServices: false)
        XCTAssertFalse(model.isNavigationActive)
        XCTAssertFalse(model.deviceReady)
        XCTAssertEqual(model.totalRideDistanceM, 1_214_000)
        model.recordGPSFix(fix(0, 22.54))
        model.recordGPSFix(fix(2, 22.5401))
        XCTAssertEqual(model.totalRideDistanceM, 1_214_011.1, accuracy: 0.2)
        // No screen refresh, destination or route request is needed between
        // fixes; background delivery uses the exact same callback.
        NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification, object: nil)
        model.recordGPSFix(fix(4, 22.5402))
        XCTAssertEqual(model.totalRideDistanceM, 1_214_022.2, accuracy: 0.3)
        XCTAssertFalse(model.isNavigationActive)
        XCTAssertFalse(model.navigation.hasDestination)
        XCTAssertEqual(RideOdometer(defaults: defaults).totalDistanceM, model.totalRideDistanceM)
    }

    @MainActor func testDemoDoesNotIncreaseDistanceAndRealGpsResumesAfterDemo() throws {
        let name = "QianGPS.ModelOdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let model = AppModel(odometer: RideOdometer(defaults: defaults), startServices: false)
        defer { model.stopNavigation() }
        model.recordGPSFix(fix(0, 22.54))
        model.startDemoNavigation()
        XCTAssertTrue(model.isDemoActive)
        model.recordGPSFix(fix(2, 22.5401))
        model.recordGPSFix(fix(4, 22.5402))
        XCTAssertEqual(model.totalRideDistanceM, 1_214_000)
        model.stopNavigation()
        model.recordGPSFix(fix(6, 22.541)) // fresh anchor, no jump across demo
        XCTAssertEqual(model.totalRideDistanceM, 1_214_000)
        model.recordGPSFix(fix(8, 22.5411))
        XCTAssertEqual(model.totalRideDistanceM, 1_214_011.1, accuracy: 0.2)
    }
}
