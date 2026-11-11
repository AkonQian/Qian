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
        let store = RideOdometer(defaults: defaults, applyCycleComputerCalibration: false)
        store.record(fix(0))
        store.record(fix(2, latitude: 22.5401))
        XCTAssertEqual(store.totalDistanceM, 11.1, accuracy: 0.2)
        XCTAssertEqual(RideOdometer(defaults: defaults, applyCycleComputerCalibration: false).totalDistanceM, store.totalDistanceM)
        let saved = store.totalDistanceM
        store.resetSegment()
        store.record(fix(3, latitude: 22.541))
        XCTAssertEqual(store.totalDistanceM, saved)
    }

    func testStationaryDriftPoorAccuracyDuplicatesGapsAndJumpsDoNotCount() throws {
        let name = "QianGPS.OdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = RideOdometer(defaults: defaults, applyCycleComputerCalibration: false)
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

    func testCycleComputerCalibrationReplacesPreviousReadingAndPersistsOnlyOnce() throws {
        let name = "QianGPS.OdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set(1_200_800.0, forKey: "QianGPS.TotalRideDistanceM.v1")
        defaults.set(true, forKey: "QianGPS.OdometerCalibration.20261110.1200_8km.v1")
        defaults.set("keep-this-gateway", forKey: "unrelated-setting")
        let store = RideOdometer(defaults: defaults)
        XCTAssertEqual(store.totalDistanceM, 1_214_000)
        XCTAssertEqual(defaults.double(forKey: "QianGPS.TotalRideDistanceM.v1"), 1_214_000)
        XCTAssertEqual(defaults.string(forKey: "unrelated-setting"), "keep-this-gateway")
        store.record(fix(0))
        store.record(fix(2, latitude: 22.5401))
        XCTAssertEqual(store.totalDistanceM, 1_214_011.1, accuracy: 0.2)
        XCTAssertEqual(RideOdometer(defaults: defaults).totalDistanceM, store.totalDistanceM)
        XCTAssertEqual(RideOdometer(defaults: defaults).totalDistanceM, store.totalDistanceM)
    }

    func testFreshPersonalInstallStartsAtCalibratedDistanceAndSyncsMeters() throws {
        let name = "QianGPS.OdometerTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let store = RideOdometer(defaults: defaults)
        XCTAssertEqual(store.totalDistanceM, 1_214_000)
        let packet = PhoneWatchTelemetry.encode(date: Date(timeIntervalSince1970: 1_794_190_080),
                                               timezone: TimeZone(secondsFromGMT: 28_800)!,
                                               odometerM: store.totalDistanceM)
        let meters = packet[8...11].enumerated().reduce(UInt32(0)) { result, item in
            result | (UInt32(item.element) << (item.offset * 8))
        }
        XCTAssertEqual(meters, 1_214_000)
    }
}
