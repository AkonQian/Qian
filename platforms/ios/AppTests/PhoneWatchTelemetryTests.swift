import Foundation
import XCTest
@testable import MOTO_GPS

final class PhoneWatchTelemetryTests: XCTestCase {
    func testPacketMatchesFirmwareLittleEndianClockAndLifetimeDistance() {
        let data = PhoneWatchTelemetry.encode(date: Date(timeIntervalSince1970: 1_794_190_080), timezone: TimeZone(secondsFromGMT: 28_800)!, odometerM: 128_600.9)
        XCTAssertEqual(Array(data), [1,3,0,43,241,106,224,1,88,246,1,0])
        XCTAssertEqual(data.count, 12)
    }
    func testUnknownDistanceAndNegativeTimezone() {
        let data = PhoneWatchTelemetry.encode(date: Date(timeIntervalSince1970: 1_794_190_080), timezone: TimeZone(secondsFromGMT: -18_000)!, odometerM: .nan)
        XCTAssertEqual(data[1], 1)
        XCTAssertEqual(Array(data[6...7]), [212,254])
        XCTAssertEqual(Array(data[8...11]), [0,0,0,0])
    }
}
