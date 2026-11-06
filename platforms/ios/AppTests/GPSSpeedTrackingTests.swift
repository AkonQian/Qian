import Foundation
import MotoNavigationCore
import XCTest
@testable import MOTO_GPS

final class GPSSpeedTrackingTests: XCTestCase {
    @MainActor
    private final class Location: NavigationLocationSource {
        var callback: (@MainActor (NavigationFix) -> Void)?
        var denied = false
        func start(onFix: @escaping @MainActor (NavigationFix) -> Void,
                   onFailure: @escaping @MainActor (String) -> Void) throws {
            callback = onFix
            if denied { throw NavigationSourceError.permissionDenied }
        }
        func stop() { callback = nil }
        func emit(speed: Double, seconds: Double) {
            callback?(NavigationFix(coordinate: WGS84Point(longitudeDeg: 114.05, latitudeDeg: 22.54),
                horizontalAccuracyM: 5, speedMps: speed, courseDeg: 90,
                timestamp: Date(timeIntervalSince1970: seconds)))
        }
    }
    private actor Routes: NavigationRouteProviding {
        var calls = 0
        func route(for request: RouteRequest) async throws -> RouteEnvelope {
            calls += 1
            throw NavigationSourceError.unavailable("No route expected for GPS speed")
        }
    }

    @MainActor
    func testIdleGPSSpeedNeedsNoDestinationOrNetworkAndExpires() async throws {
        let location = Location(), routes = Routes()
        let runtime = SharedNavigationRuntime(locationSource: location, routeProvider: routes)
        defer { runtime.stop() }
        var snapshot: MotoNavCoreSnapshot?
        runtime.onSnapshot = { snapshot = $0 }
        XCTAssertTrue(runtime.startTracking(displayPageName: "speed"))
        location.emit(speed: 10, seconds: 1_000)
        let moving = try XCTUnwrap(snapshot)
        XCTAssertEqual(moving.stateName, "idle")
        XCTAssertFalse(moving.hasDestination)
        XCTAssertFalse(moving.routeRequestInFlight)
        XCTAssertFalse(moving.trafficRequestInFlight)
        XCTAssertTrue(moving.hasUsableFix)
        XCTAssertFalse(moving.gnssStale)
        XCTAssertEqual(moving.speedMPS * 3.6, 36, accuracy: 0.01)
        XCTAssertEqual(moving.displayPageName, "speed")
        XCTAssertTrue(runtime.selectDisplayPage(rawValue: 2))
        location.emit(speed: 0, seconds: 1_001)
        XCTAssertEqual(snapshot?.displayPageName, "compass")
        XCTAssertEqual(snapshot?.speedMPS, 0)
        location.emit(speed: 8, seconds: 1_002)
        runtime.tick(atMs: 1_008_000)
        XCTAssertTrue(try XCTUnwrap(snapshot).gnssStale)
        XCTAssertEqual(snapshot?.speedMPS, 0)
        location.emit(speed: 5, seconds: 1_009)
        XCTAssertFalse(try XCTUnwrap(snapshot).gnssStale)
        XCTAssertEqual(snapshot?.speedMPS, 5)
        let calls = await routes.calls
        XCTAssertEqual(calls, 0)
    }

    @MainActor
    func testEndingNavigationCanResumeGPSOnTheSelectedPage() async throws {
        let location = Location(), routes = Routes()
        let runtime = SharedNavigationRuntime(locationSource: location, routeProvider: routes)
        defer { runtime.stop() }
        var snapshot: MotoNavCoreSnapshot?
        runtime.onSnapshot = { snapshot = $0 }
        XCTAssertTrue(runtime.start(destination: WGS84Point(longitudeDeg: 114.1, latitudeDeg: 22.6), displayPageName: "compass"))
        XCTAssertTrue(try XCTUnwrap(snapshot).hasDestination)
        XCTAssertTrue(runtime.startTracking(displayPageName: "compass"))
        location.emit(speed: 6, seconds: 1_000)
        XCTAssertFalse(try XCTUnwrap(snapshot).hasDestination)
        XCTAssertEqual(snapshot?.stateName, "idle")
        XCTAssertEqual(snapshot?.displayPageName, "compass")
        XCTAssertEqual(snapshot?.speedMPS, 6)
        let calls = await routes.calls
        XCTAssertEqual(calls, 0)
    }

    @MainActor
    func testGrantingPermissionLaterStillHasFreshnessChecks() throws {
        let location = Location()
        location.denied = true
        let runtime = SharedNavigationRuntime(locationSource: location, routeProvider: Routes())
        defer { runtime.stop() }
        var snapshot: MotoNavCoreSnapshot?, failure: String?
        runtime.onSnapshot = { snapshot = $0 }
        runtime.onFailure = { failure = $0 }
        XCTAssertFalse(runtime.startTracking())
        XCTAssertNotNil(failure)
        XCTAssertFalse(try XCTUnwrap(snapshot).hasUsableFix)
        location.emit(speed: 5, seconds: 1_000)
        XCTAssertTrue(try XCTUnwrap(snapshot).hasUsableFix)
        runtime.tick(atMs: 1_006_000)
        XCTAssertTrue(try XCTUnwrap(snapshot).gnssStale)
        XCTAssertEqual(snapshot?.speedMPS, 0)
    }
}
