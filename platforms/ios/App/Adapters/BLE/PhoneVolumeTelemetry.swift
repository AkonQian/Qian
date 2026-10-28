@preconcurrency import CoreBluetooth
import AVFAudio
import Foundation
import UIKit

/// Read-only system media-volume observation. It never records, plays sound,
/// changes the volume, or becomes the Now Playing music source.
@MainActor
final class PhoneVolumeTelemetry {
    static let uuid = CBUUID(string: MotoBLEProtocolCodec.phoneVolumeUUIDString())
    private weak var peripheral: CBPeripheral?
    private var characteristic: CBCharacteristic?
    private let session = AVAudioSession.sharedInstance()
    private var observation: NSKeyValueObservation?
    private var foregroundToken: NSObjectProtocol?
    private var interruptionToken: NSObjectProtocol?
    private var routeToken: NSObjectProtocol?
    private var active = false
    private var inFlight = false
    private var pending: UInt8?
    private var lastSentAt = Date.distantPast

    nonisolated static func encode(volume: Float?) -> Data {
        guard let volume, volume.isFinite, (0...1).contains(volume) else {
            return Data([1, 255])
        }
        return Data([1, UInt8((volume * 100).rounded())])
    }

    func attach(_ peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        if self.peripheral === peripheral, self.characteristic === characteristic { return }
        detach()
        self.peripheral = peripheral
        self.characteristic = characteristic
        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            guard let value = change.newValue else { return }
            Task { @MainActor [weak self] in self?.publish(volume: value) }
        }
        foregroundToken = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.refresh() } }
        routeToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification, object: session, queue: .main
        ) { [weak self] _ in Task { @MainActor [weak self] in self?.refresh() } }
        interruptionToken = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: session, queue: .main
        ) { [weak self] note in
            let began = (note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt)
                == AVAudioSession.InterruptionType.began.rawValue
            Task { @MainActor [weak self] in
                guard let self else { return }
                if began { self.active = false; self.publish(volume: nil) }
                else { self.refresh() }
            }
        }
        refresh()
    }

    func detach() {
        observation?.invalidate(); observation = nil
        [foregroundToken, interruptionToken, routeToken].compactMap { $0 }.forEach {
            NotificationCenter.default.removeObserver($0)
        }
        foregroundToken = nil; interruptionToken = nil; routeToken = nil
        peripheral = nil; characteristic = nil
        inFlight = false; pending = nil; lastSentAt = .distantPast
        active = false
    }

    /// Called on each connected BLE heartbeat as well as on volume/route
    /// changes. No fake audio background mode or silent audio is used.
    func refresh() {
        guard peripheral != nil, characteristic != nil else { return }
        if !active {
            do {
                // Ambient mixes with Soda Music rather than interrupting it.
                try session.setCategory(.ambient, mode: .default)
                try session.setActive(true)
                active = true
            } catch {
                publish(volume: nil)
                return
            }
        }
        publish(volume: session.outputVolume)
    }

    private func publish(volume: Float?) {
        pending = Self.encode(volume: active ? volume : nil)[1]
        flush()
    }

    private func flush() {
        guard !inFlight, let pending, let peripheral, let characteristic,
              peripheral.state == .connected, Date().timeIntervalSince(lastSentAt) >= 0.1 else { return }
        self.pending = nil
        inFlight = true
        lastSentAt = Date()
        peripheral.writeValue(Data([1, pending]), for: characteristic, type: .withResponse)
    }

    func writeCompleted(error: Error?) {
        inFlight = false
        if error != nil { active = false }
        flush()
    }
}
