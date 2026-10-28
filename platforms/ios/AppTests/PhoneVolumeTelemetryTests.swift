import Foundation
import CoreBluetooth
import XCTest
@testable import MOTO_GPS

final class PhoneVolumeTelemetryTests: XCTestCase {
    @MainActor func testCachedBadgeCharacteristicsStillDiscoverNewVolumeChannel() {
        let oldCache = [BadgeTransferClient.rxUUID, BadgeTransferClient.txUUID]
        var discovery = BLEAccessoryDiscovery()
        XCTAssertTrue(discovery.needsDiscovery(oldCache))
        XCTAssertFalse(discovery.needsDiscovery(oldCache)) // old firmware: no rediscovery loop
        let fresh = oldCache + [PhoneVolumeTelemetry.uuid]
        XCTAssertFalse(discovery.needsDiscovery(fresh))
        discovery = BLEAccessoryDiscovery() // reconnect/restoration starts a new discovery pass
        XCTAssertTrue(discovery.needsDiscovery(oldCache))
        discovery = BLEAccessoryDiscovery()
        XCTAssertFalse(discovery.needsDiscovery(fresh))
    }
    func testSystemVolumePacketUsesActualRoundedValueAndUnknownSentinel() {
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: 0), Data([1, 0]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: 1), Data([1, 100]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: 0.375), Data([1, 38]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: nil), Data([1, 255]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: .nan), Data([1, 255]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: .infinity), Data([1, 255]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: -0.1), Data([1, 255]))
        XCTAssertEqual(PhoneVolumeTelemetry.encode(volume: 1.1), Data([1, 255]))
    }

    @MainActor func testBadgeOnlyExposesThreeSlotsWhileDecodingOldFourSlotCatalogs() throws {
        XCTAssertEqual(BadgeTransferClient.slotCount, 3)
        XCTAssertTrue(BadgeTransferClient.validSlot(0))
        XCTAssertTrue(BadgeTransferClient.validSlot(2))
        XCTAssertFalse(BadgeTransferClient.validSlot(-1))
        XCTAssertFalse(BadgeTransferClient.validSlot(3))
        let client = BadgeTransferClient()
        let reply = Data([0x42, 0x47, 1, 0x81, 1, 0, 0, 0,
                          0, 0, 5, 0, 0, 0, 0, 0, 3, 1, 0, 2, 1])
        client.receive(reply, error: nil)
        XCTAssertEqual(client.formats, [1, 0, 2])
        XCTAssertEqual(client.selected, 255) // obsolete fourth photo is preserved but hidden
        client.detach()
        XCTAssertEqual(client.formats.count, 3)
    }
}
