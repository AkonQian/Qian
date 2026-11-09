@preconcurrency import CoreBluetooth
import Foundation

/// Optional A006 channel; does not change navigation-v1 or require internet.
@MainActor final class PhoneWatchTelemetry {
    static let uuid = CBUUID(string: "7E57A006-B50C-4B6A-9C57-40A54E8E1000")
    private weak var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private var inFlight = false
    private var lastSentAt = -Double.infinity
    private var lastOdometer: Double = -1
    var odometerM: Double = 0

    nonisolated static func encode(date: Date, timezone: TimeZone, odometerM: Double?) -> Data {
        let utc = date.timeIntervalSince1970
        let clockValid = utc.isFinite && utc >= 1_704_067_200 && utc <= 4_102_444_800
        let odometerValid = odometerM.map { $0.isFinite && $0 >= 0 } ?? false
        var result = Data([1, (clockValid ? 1 : 0) | (odometerValid ? 2 : 0)])
        var seconds = UInt32(clockValid ? utc : 0).littleEndian
        var offset = Int16(clamping: timezone.secondsFromGMT(for: date) / 60).littleEndian
        var meters = UInt32(odometerValid ? min(odometerM!, Double(UInt32.max)).rounded(.down) : 0).littleEndian
        withUnsafeBytes(of: &seconds) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &offset) { result.append(contentsOf: $0) }
        withUnsafeBytes(of: &meters) { result.append(contentsOf: $0) }
        return result
    }
    func attach(_ peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        if self.peripheral === peripheral, self.characteristic === characteristic { return }
        detach(); self.peripheral = peripheral; self.characteristic = characteristic; refresh()
    }
    func detach() { peripheral = nil; characteristic = nil; inFlight = false; lastSentAt = -.infinity; lastOdometer = -1 }
    func refresh() {
        let now = ProcessInfo.processInfo.systemUptime
        guard !inFlight, let peripheral, let characteristic, peripheral.state == .connected,
              now - lastSentAt >= 1, now - lastSentAt >= 10 || abs(odometerM - lastOdometer) >= 1 else { return }
        inFlight = true; lastSentAt = now; lastOdometer = odometerM
        peripheral.writeValue(Self.encode(date: Date(), timezone: .current, odometerM: odometerM), for: characteristic, type: .withResponse)
    }
    func writeCompleted(error: Error?) { inFlight = false; if error != nil { lastSentAt = -.infinity } }
}
